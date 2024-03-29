#!/usr/bin/perl
#
#	Apple Mobile report
#	https://covid19.apple.com/mobility
#
#	Complete Data
#	https://covid19-static.cdn-apple.com/covid19-mobility-data/2025HotfixDev13/v3/en-us/applemobilitytrends-2021-01-25.csv
#
#	0        1      2                   3                4          5       6         7
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020/1/13,2020/1/14,2020/1/15,2020/1/16
#	country/region,Japan,driving,日本,Japan-driving,,100,97.94,99.14,103.16
#
#	CSV_DEF
#		src_url => source_url of data,
#		src_csv => download csv data,
#		keys => [1, 2],		# region, transport
#		date_start => 6,	# 2020/01/13
#		html_title => "Apple Mobility Trends",
#	GRAPH_PARAMN
#		dsc => "Japan"
#		lank => [1,999],
#		graph => "LINE | BOX",
#		statics => "RLAVR",
#		target_area => "Japan,XXX,YYY", 
#		exclusion_are => ""
#
#
use strict;
use warnings;
#use encoding "cp932";
use utf8;
use Encode 'decode';
use Data::Dumper;
use List::Util 'min';
use POSIX ":sys_wait_h";
use Proc::Wait3;
use Time::HiRes qw( usleep gettimeofday tv_interval );

use config;
use csvlib;
use csv2graph;
use dp;

use defamt;
use defccse;
use defjapan;
use deftokyo;
use deftkow;
use defdocomo;
use defmhlw;
use deftkocsv;
use defjpvac;
use defowid;
use defnhk;
use tkopdf;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $VERBOSE = 0;
my $DOWNLOAD = 1;

my $WIN_PATH = $config::WIN_PATH;
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $DEFAULT_AVR_DATE = 7;
my $END_OF_DATA = "###EOD###";

my $WEEK_BEFORE = 4;
my $THRESH_POP_NC_LAST_JP = 1.0; #0.5;
my $THRESH_POP_NC_LAST_WW = 5.0; #0.5;
my $mainkey = $config::MAIN_KEY;

my $DOWN_LOAD = 1;
my $RECENT = "2022-01-01"; #-210; #-93; # -62;		# recent = 2month
my $RECENT_MONTH = -42;
my $RECENT_2MONTH = -7 * 9;
my $RECENT_ERN = -7 * 30;
my @RECENTS = ($RECENT, $RECENT_MONTH);
my $CCSE_MAX_REGION = 30;
my $TERM_Y_SIZE = 400;

#my 	$line_thick = $csv2graph::line_thick;
#my	$line_thin = $csv2graph::line_thin;
#my	$line_thick_dot = $csv2graph::line_thick_dot;
#my	$line_thin_dot = $csv2graph::line_thin_dot;
#my	$box_fill = $csv2graph::box_fill;

my $line_thick 	= "line linewidth 2";
my $line_thin 		= "line linewidth 1" ;
my $line_thick_dot = "line linewidth 2 dt(7,3)";
my $line_thin_dot 	= "line linewidth 1 dt(6,4)";
my $line_thin_dot2 	= "line linewidth 1 dt(2,6)";
my $line_thick_jp 	= "line linewidth 2 dt(8,2) lc rgb 'red'";
my $box_fill  		= "boxes fill";
my $box_fill_solid 	= 'boxes fill solid border lc rgb "white" lw 1';

my $y2y1rate = 2.5;
my $end_target = 0;
my $CCSE_MAX = 119; # 99;

my $POP_YMAX_NC_WW = 200; #150;# 800; #120;		# WW YMAX(positive) * pop100k, positive_death_ern
my $POP_YMAX_ND_WW = 0.4; #2.0;		# WW Y2MAX(deaths)  * pop100k, positive_death_ern
my $POP_YMAX_NC_JP = 250;#150; #150;#60; #40;		# JP YMAX(positive) * pop100k, positive_death_ern
my $POP_YMAX_NC_JP_SHORT = 250;#150;#60; #2;		# JP YMAX(positive) * pop100k, positive_death_ern
my $POP_YMAX_ND_JP = 0.4; #0.2;		# JP Y2MAX(deaths)  * pop100k, positive_death_ern

my $GEN_REPORT = 1;

#
#	for APPLE Mobility Trends
#
my $SRC_URL_TAG = "https://covid19-static.cdn-apple.com/covid19-mobility-data/2025HotfixDev13/v3/en-us/applemobilitytrends-%04d-%02d-%02d.csv";
my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
my $src_url = sprintf($SRC_URL_TAG, $year + 1900, $mon + 1, $mday);
my $ern_adp	= "1 with lines title 'ern=1' lw 1 lc 'red' dt (3,7)";

my $REG = $defamt::REG;
my $SUBR = $defamt::SUBR;
my $CITY = $defamt::CITY;
my $DRV = $defamt::DRV;
my $TRN = $defamt::TRN;
my $WLK = $defamt::WLK;
my $AVR = $defamt::AVR;

my $prov = "Province/State";
my $cntry = "Country/Region";

my $positive = "testedPositive";
my $deaths = "deaths";

my @ALL_PARAMS = qw/mhlw-pref ccse pref tko-age ccse-tgt mhlw mhlw-pref nhk usa pref-ern ccse-ern ccse-order/; # jpvac owidvac 

#my @ALL_PARAMS = qw/ccse-tgt nhk/;
my $GKIND = "";		# for pref, and ccse
my $DELAY_AT_ALL = 1;

#
#	For CCSE, Johns holkins University
#
#my @CCSE_TARGET_REGION = (
#		"Canada", "Japan", "US", # ,United States",
#		"United Kingdom", "France", #"Spain", "Italy", "Russia", 
#			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
#			"Belgium", "Portugal", "Sweden",
#		"India",  "Indonesia", "Israel", # "Iran", "Iraq","Pakistan",
#		"Brazil", "Colombia", "Argentina", "Chile", "Mexico", "Canada", 
#		"South Africa", 
#);

#
#	Form Marge data (amt and ccse-ern)
#
my $MARGE_CSV_DEF = {
	id => "amt-ccse",
	title => "MARGED Apple and ERN pref",
	main_url =>  "Marged, no url",
	csv_file =>  "Marged, no csv file",
	src_url => 	"Marged, no src url",		# set
};


my %additional_plot_item = (
	amt => "100 axis x1y1 with lines title '100%' lw 1 lc 'blue' dt (3,7)",
	ern => "1 axis x1y2 with lines title 'ern=1' lw 1 lc 'red' dt (3,7)",
	docomo => "0 axis x1y1 with lines title '0' lw 1 lc 'red' dt (3,7)",
);
my $additional_plot = join(",", values %additional_plot_item);


my @TARGET_REGION = (
		"Japan", "US,United States", "India", "Brazil", "Peru",
		"United Kingdom", "France", "Spain", "Italy", "Russia", "Germany", "Ireland",
			"Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
			"Belgium", "Portugal", "Sweden", 
			"Estonia", "Romania", "Bulgaria", "Hungary", "Slovakia", "Slovenia", 
		"China", "Taiwan*", "Singapore", "Vietnam", "Malaysia", "Korea-South", 
		"Indonesia", "Israel", "Iran", "Iraq","Pakistan", #different name between amt and ccse  
		"Colombia", "Argentina", "Chile", "Mexico", "Canada", 
		"South Africa", "Seychelles", 
		"Australia", "New Zealand","Singapore",
);

my	@TARGET_EU = ( "Russia", "United Kingdom", "Ukraine", "Spain", "Romania", "Hungary", "Bulgaria", "Belgium", "Netherlands", 
					"Greece", "France", "Italy", "Austria", "Montenegroi", "Germany", "Luxembourg", "Slovenia", "Iceland",	"Switzerland", 	
					"Malta", "Latvia", 	"Portugal", "Serbia", "Finland");

my @TARGET_PREF = ("Tokyo", "Kanagawa", "Chiba", "Saitama", "Kyoto", "Osaka");

my @cdp_list = ($defamt::AMT_DEF, $defccse::CCSE_DEF, $MARGE_CSV_DEF, 
					$deftokyo::TOKYO_DEF, $defjapan::JAPAN_DEF, $deftkow::TKOW_DEF, $defdocomo::DOCOMO_DEF, 
					$deftkocsv::TKOCSV_DEF, $defjpvac::VACCINE_DEF, $defowid::OWID_VAC_DEF,
					$defnhk::CDP); 

my $cmd_list = {"amt-jp" => 1, "amt-jp-pref" => 1, "tkow-ern" => 1, try => 1, "pref-ern" => 1, 
				pref => 1, mhlw => 1, docomo => 1, upload => 1, "ccse-tgt" => 1, "mhlw-pref" => 1,
				usa => 1, ccse_jp_term => 1, "ccse-ern" => 1, "ccse-order" => 1, "tko-age" => 1};
my @REG_INFO_LIST = ();

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
		elsif(/^-gk/){
			$GKIND = $ARGV[++$i];
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
		elsif(/^-poplist/){
			print "$config::POPF\n";
			system("cat $config::POPF");
			print "$config::POPF\n";
			exit;
		}
		elsif(/-DL/){
			$DOWNLOAD = ($i < $#ARGV && !($ARGV[$i+1] =~ /\D/)) ? $ARGV[++$i] : 1;
			next;
		}
		elsif(/-no_report/){
			$GEN_REPORT = 0;
		}
		elsif($_ eq "try"){
			$golist{pref} = 1;
			$golist{"pref-ern"} = 1;
			$golist{docomo} = 1;
			next;
		}
		elsif($cmd_list->{$_}){
			$golist{$_} = 1;
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
	dp::dp "usage:$0 " . join(" | ", "-all", @ids, keys %$cmd_list, "-et | -poplist") ."\n";
	exit;
}

dp::dp "Parames: " . join(",", keys %golist) . "\n";

#if($golist{"amt-ccse"}){
#	$golist{amt} = 1;
#	$golist{ccse} = 1;
#}
##########################
#
#
my $child_list = {};
my @allp = ();
my @pid_list = ();
my %start_time = ();
my $tm_start = time;
my $child_procs = 0;

sub sigchld
{
	my ($sig) = @_;

	for(my $i = 0;;$i++){
		my ($pid, $status, $utime, $stime, $maxrss, $ixrss, $idrss, $isrss,
		$minflt, $majflt, $nswap, $inblock, $oublock, $msgsnd, $msgrcv,
		$nsignals, $nvcsw, $nivcsw) = wait3(0);

		if(!defined $pid){
			#dp::dp "SIGCHLD:[$sig][pid=''] $i\n";
			return;
		}
		#my $pid = waitpid(-1, &WNOHANG); 
		dp::dp "SIGCHLD:[$sig][$pid] $i\n";

		return if(!$pid || $pid <= 0);
		
		my $etm = time;
		$child_list->{$pid}->{st} = $status;
		$child_list->{$pid}->{end_time} = $etm;
		$child_list->{$pid}->{elp_time} = $etm - $child_list->{$pid}->{start_time};
		$child_list->{$pid}->{sig} = "SIG";
		$child_procs--;
	} 
}

#
#	When SIG{CHLD} is set, sleep exit when SIGNAL occured
#
sub	sleep_child
{
	my ($wait) = @_;
	my $t0 = gettimeofday();
	my $end = $t0 + $wait;

	for(;;){
		my $now = gettimeofday();
		my $diff = $end - $now ;
		#dp::dp "$now $end : " . sprintf("%.3f", $diff) . "\n";
		last if($now >= $end);

		usleep($diff * 1000 * 1000);
	}
}

sub	forkc
{
	my($id, $gkind) = @_;
	
	#dp::dp "$id: $gkind\n";
	my $pid = fork;
	dp::ABORT "cannot fork $!" if(! defined $pid);

	if(! $pid){		# Child Process
		dp::set_dp_id("child");
		%golist = ($id => 1);
		$GKIND = $gkind;
		#dp::dp "gkind:[$gkind]\n";
		return "";
	}
	else {			# main process
		$child_list->{$pid} = {id => $id, gkind => $gkind, start_time => time, cn => $child_procs++};
		push(@pid_list, $pid);
		dp::dp "fork $id $gkind: [$pid] " . csvlib::ut2t(time) . "\n";
		#&sleep_child(2);
		return $pid;
	}
}

if($all || $GKIND eq "all"){
	dp::dp "##### all\n";
	$SIG{CHLD} = 'sigchld';
	my $last_flag = "";
	my  @glist = ();
	my $delay = ($db_all) ? 1 : 20;
	my @params = (@ALL_PARAMS);
	if(!$all){
		@params = ();
		foreach my $cmd (keys %golist){
			push(@params, $cmd);
		}
		%golist = ();
	}
	foreach my $gk ("raw", "rlavr", "pop"){
		foreach my $id (@params){
			if($id eq "pref" || $id =~ /ccse/){
				push(@glist, {id => $id, gkind => $gk, delay => $delay});
			}
			elsif($gk eq "raw") {
				push(@glist, {id => $id, gkind => "", delay => 2});
			}
		}
	}

	my $pid = -1;
	for(; $#glist >= 0;){
		$pid = -1;
		my @w = ();									# for debug
		for(my $i = 0; $i <= $#glist; $i++){		# 
			my $gp = $glist[$i];
			push(@w, $gp->{id} . ":". $gp->{gkind});
		}
		dp::dp "## glist: " . join(",", $#w, @w) . "\n";

		for(my $i = 0; $i <= $#glist; $i++){		# execute child proc (@glist);
			my $gp = $glist[$i];

			my $ws = 5;
			while($child_procs >= 2){
				dp::dp "######## Wait Child proc $child_procs wait $ws sec\n";
				sleep $ws;
			}

			dp::dp "EXECUTE: " . join(": ", $gp->{id}, $gp->{gkind}, $gp->{delay}) . "\n";
			$pid = &forkc($gp->{id}, $gp->{gkind});		# set id to golist and GKIND 
			last if(! $pid);

			#dp::dp "wait " . $gp->{delay} . "\n";
			&sleep_child($gp->{delay} // 1);
		}
		
		@glist = ();	# clear glist for retry error process
		if($pid){		# main,  Wait child process 
			#&sleep_child(2);
			dp::set_dp_id("main");
			my $kid = 0;
			for(my $conf = 0; $conf < 500 && $child_procs > 0; $conf++){

				$kid = waitpid(-1, WNOHANG); 
				dp::dp "WAIT CHILD $conf: $kid $child_procs\n";
				foreach $pid (keys %$child_list){
					my $p = $child_list->{$pid};
					if(($p->{st}//0) == 256){
						dp::dp "WARNING: " . join(": ", $p->{id}, $p->{gkind}, $p->{st}) . "\n";
						$p->{st} = -1;
						push(@glist, {id => $p->{id}, gkind => $p->{gkind}, delay => 2});
					}
				}
				&sleep_child(2);
			}
		}
	}

	my $tm_end = time;
	if($pid && $golist{upload}) {
		my $do = "$0 upload";
		dp::dp $do . "\n";
		my $pid = "upload";
		push(@pid_list, $pid);
		$child_list->{$pid} = {id => "upload", gkind => "", start_time => time, cn => 9999};
		system($do);
		my $etm = time;
		$child_list->{$pid}->{st} = $?;
		$child_list->{$pid}->{end_time} = $etm;
		$child_list->{$pid}->{elp_time} = $etm - $child_list->{$pid}->{start_time};
	}
	if($pid){
		my $tm_up_end = time ;
		my $elp1 = $tm_end  - $tm_start;
		my $elp2 = $tm_up_end  - $tm_start;
		dp::dp sprintf("\ndone elp %02d:%02d %02d:%02d   %s %s %s (%s)\n", 
				int($elp1/60), $elp1 % 60, int($elp2/60), $elp2 % 60, 
				csvlib::ut2t($tm_start), csvlib::ut2t($tm_end), csvlib::ut2t($tm_up_end),
				join(",", @ALL_PARAMS)
		);

		foreach my $pid (@pid_list){
			my $p = $child_list->{$pid};
			dp::dp sprintf("%2d: $pid %-20s elp %02d:%02d (%s) %s %s  %s\n", 
				$p->{cn}, $p->{id}. "#". $p->{gkind}, 
				int(($p->{elp_time}//0)/60), ($p->{elp_time}//0) % 60,$p->{st}//"", 
				csvlib::ut2t($p->{start_time}//0), csvlib::ut2t($p->{end_time}//0),
				$p->{sig} // "-",
			);
		}
		exit;
	}
	if($db_all){	# for debug, multitask, exit when child process
		srand();
		&sleep_child(2);

		exit (rand(10) > 7) ? 0 : 1;
	}
}

#	POP
my %POP = ();
csvlib::cnt_pop(\%POP);	

#
#	Load Johns Hoping Univercity CCSE
#
#	Province/State,Country/Region,Lat,Long,1/22/20
#
my $gp_list = [];
my $ccse_country = {};

my $PREF_LIST = {};

#
#	Try for using 
#
#
if($golist{pref}){
	dp::dp "gkind: [[$GKIND]]\n";
	dp::set_dp_id("pref $GKIND");
	my $pd_list = [];
	my $pd_pop_list = [];
	my $pd_rlavr_list = [];

	@REG_INFO_LIST = ();
	#
	#	ccse Japan
	#
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv({download => $DOWNLOAD});
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	#$ccse_country->dump();
	#exit;

	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv({download => $DOWNLOAD});
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	my $graph_kind = $csv2graph::GRAPH_KIND;

	my $region = "Japan";

	#
	#	Japan Prefectures	NHK
	#
	my $jp_cdp = csv2graph->new($defnhk::CDP); 						# Load Johns Hopkings University CCSE
	$jp_cdp->load_csv({download => $DOWNLOAD});

	my $jp_pcdp = &mhlw_cdp("positive");
	dp::ABORT "no data at MHLW_DEFS(positive)\n" if(!$jp_pcdp);
	my $jp_prlavr = $jp_pcdp->calc_rlavr($jp_pcdp);

	my $jp_dcdp = &mhlw_cdp("deaths");
	dp::ABORT "no data at MHLW_DEFS(death)\n" if(!$jp_dcdp);
	my $jp_drlavr = $jp_dcdp->calc_rlavr($jp_dcdp);

	#
	#	Generate HTML FILE
	#
	my $target_keys = [$jp_prlavr->select_keys("")];	# select data for target_keys
	my $sorted_keys = [$jp_prlavr->sort_csv($jp_prlavr->{csv_data}, $target_keys, $RECENT, 0)];
	shift(@$sorted_keys);		# remove ALL 
	my $endt = ($end_target <= 0) ? (scalar(@$sorted_keys) -1) : ($end_target - 1);
	dp::dp "endt : [$endt]\n";
	foreach my $pref (@$sorted_keys[0..$endt]){
		$pref =~ s/[\#\-].*$//;
		dp::dp "$GKIND: $pref\n";
		foreach my $start_date (0, $RECENT, $RECENT_MONTH){ # , $RECENT)
			if(!$GKIND || $GKIND eq "raw"){		# 0 -> 1 2021.06.28
				my @gpd = &japan_positive_death_ern($jp_pcdp, $jp_dcdp, $pref, $start_date, 1, "raw") ;
				push(@$pd_list, @gpd);
				#&set_list($PREF_LIST, $gpd, $pref, "pref", "raw", "raw", $start_date, $gpd);
			}
			if(!$GKIND || $GKIND eq "rlavr"){		# 0 -> 1 2021.06.28
				my @gpd = &japan_positive_death_ern($jp_pcdp, $jp_dcdp, $pref, $start_date, 0, "rlavr") if(!$GKIND || $GKIND eq "rlavr");		# 0 -> 1 2021.06.28
				push(@$pd_rlavr_list, @gpd);
				#&set_list($PREF_LIST, $gpd, $pref, "pref", "raw", "rlavr", $start_date, $gpd);
			}
		}
	}

	if(!$GKIND || $GKIND eq "pop"){
		my $jp_ppop_rlavr   = $jp_prlavr->calc_pop($jp_prlavr);
		my $jp_dpop_rlavr   = $jp_drlavr->calc_pop($jp_drlavr);
		$sorted_keys = [$jp_ppop_rlavr->sort_csv($jp_ppop_rlavr->{csv_data}, $target_keys, $RECENT, 0)];
		foreach my $pref (@$sorted_keys[0..$endt]){
			$pref =~ s/[\#\-].*$//;
			dp::dp "pop: $pref\n";
			foreach my $start_date (0, $RECENT, $RECENT_MONTH){ # , $RECENT)
				my @gpd = &japan_positive_death_ern($jp_pcdp, $jp_dcdp, $pref, $start_date, 1, "pop");
				push(@$pd_pop_list, @gpd);
				#&set_list($PREF_LIST, $pref, "pref", "pop", "rlavr", $start_date, $gpd);
			}
		}

		csv2graph->gen_html_by_gp_list($pd_pop_list, {						# Generate HTML file with graphs
				row => 3,
				no_lank_label => 1,
				html_tilte => "POP Positve/Deaths COVID-19 Japan prefecture ",
				src_url => "src_url",
				html_file => "$HTML_PATH/japanpref_pop.html",
				alt_graph => "./japanpref_rlavr.html",
				png_path => $PNG_PATH // "png_path",
				png_rel_path => $PNG_REL_PATH // "png_rel_path",
				data_source => $jp_cdp->{src_info},
			}
		);
		my $reg_param = {graph_html => "./japanpref_pop.html"};
		&gen_reginfo("$HTML_PATH/japanpref_ri_", $reg_param, "nc_pop_last", "nc_pop_max");
		&gen_reginfo("$HTML_PATH/japanpref_ri_", $reg_param, "nc_pop_max", "nc_pop_last");
		&gen_reginfo("$HTML_PATH/japanpref_ri_", $reg_param, "nd_pop_last", "nd_pop_max");
		&gen_reginfo("$HTML_PATH/japanpref_ri_", $reg_param, "nd_pop_max", "nd_pop_last");
		&gen_reginfo("$HTML_PATH/japanpref_ri_", $reg_param, "drate_max");
		&gen_reginfo("$HTML_PATH/japanpref_ri_", $reg_param, "drate_last");
		&gen_reginfo("$HTML_PATH/japanpref_ri_", $reg_param, "nc_week_diff", "nd_week_diff");
		&gen_reginfo("$HTML_PATH/japanpref_ri_", $reg_param, "nd_week_diff", "nc_week_diff");
		my $reg_param_th = {graph_html => ($reg_param->{graph_html}), thresh => $THRESH_POP_NC_LAST_JP, thresh_item => "nc_pop_last"};
		&gen_reginfo("$HTML_PATH/japanpref_ri_th_", $reg_param_th, "nc_week_diff", "nd_week_diff");
	}

	if(!$GKIND || $GKIND eq "raw"){
		csv2graph->gen_html_by_gp_list($pd_list, {						# Generate HTML file with graphs
				row => 3,
				no_lank_label => 1,
				html_tilte => "Positve/Deaths COVID-19 Japan prefecture ",
				src_url => "src_url",
				html_file => "$HTML_PATH/japanpref.html",
				alt_graph => "./japanpref_rlavr.html",
				png_path => $PNG_PATH // "png_path",
				png_rel_path => $PNG_REL_PATH // "png_rel_path",
				data_source => $jp_cdp->{src_info},
			}
		);
	}

	if(!$GKIND || $GKIND eq "rlavr"){
		csv2graph->gen_html_by_gp_list($pd_rlavr_list, {						# Generate HTML file with graphs
				row => 3,
				no_lank_label => 1,
				html_tilte => "POP Positve/Deaths COVID-19 Japan prefecture ",
				src_url => "src_url",
				html_file => "$HTML_PATH/japanpref_rlavr.html",
				alt_graph => "./japanpref_pop.html",
				png_path => $PNG_PATH // "png_path",
				png_rel_path => $PNG_REL_PATH // "png_rel_path",
				data_source => $jp_cdp->{src_info},
			}
		);


	}
}


#
#
#
sub	gen_reginfo
{
	my ($outf, $p, $sort_key, @sub) = @_;
	
	$p = {} if(!($p//""));
	my $thresh = $p->{thresh}//"";
	my $thresh_item = $p->{thresh_item}//"";
	my $graph_html = $p->{graph_html}//"";
	#dp::dp "THRESH_POP: $sort_key [$thresh_item]\n";

	my $CSS = $config::CSS;
	my $class = $config::CLASS;

	my $now = csvlib::ut2t(time());
	$outf .= $sort_key . ".html";
	open(HTML, "> $outf") || die "Cannot create $outf";
	binmode(HTML, ":utf8");
	#binmode(HTML, ':encoding(cp932)');
	print HTML "<html>\n<head>\n";
	print HTML "<TITLE>$sort_key [$now]</TITLE>\n";
	print HTML "$CSS\n";
	print HTML "</head>\n<body>\n";
	
	print HTML "<span class=\"c\">\n";
	print HTML "<h1>$sort_key $thresh_item $thresh [$now]</h1>\n";
	my %DISPF = ();
	my @keys_list = ("nc_pop_last", "nc_pop_1", "nd_pop_last", "nd_pop_1", "drate_last", 
					"nc_last", "nc_last_1", "nd_last", "nd_last_1",
					"nc_pop_max",  "nd_pop_max",  "drate_max",  "nc_max", "nd_max", 
					"nc_week_diff", "nd_week_diff",
					"pop_100k",
					);
	my @keys = ();
	foreach my $k ($sort_key, @keys_list){		# $sort_key, @sub, @key_list
		#dp::WARNING "DIPF $k: " . join(",", $sort_key, @sub, @keys_list) . "\n" if(defined $DISPF{$k});

		$DISPF{$k} = 1;
		push(@keys, $k);
	}
	
	for(my $w = 0; $w < $WEEK_BEFORE; $w++){
		print HTML "<h2>week $w</h2>\n";
		print HTML "<table  border=\"1\">\n<tbody>\n";
		print HTML &table_head("# region", @keys) . "\n";
		my $n = 1;
		my $rgi = $REG_INFO_LIST[$w];
		foreach my $region (sort {$rgi->{$b}->{$sort_key} <=> $rgi->{$a}->{$sort_key}} keys %$rgi){
			#dp::dp "$w [$region]\n";
			next if($region =~ /#-/);
			if($thresh_item && $rgi->{$region}->{$thresh_item} < $thresh){
				#dp::dp "THRESH_POP: [$thresh_item] [$thresh:" . $rgi->{$region}->{$thresh_item} . "]\n";
				next;
			}

			my $r = $rgi->{$region};
			$region =~ s/#.*$//;
			$region =~ s/,.*$//;
			$region =~ s/"//;
			$region =~ s/ and /\&/;
			$region =~ s/Republic/Rep./;
			$region =~ s/Herzegovina/Herz./;
			$region =~ s/United Arab Emirates/UAE/;

			my $rstr = "<a href=\"$graph_html#$region" . "0\">" . sprintf("%3d %s", $n++, $region) . "</a>";
			#dp::dp ">>>>> $rstr\n";
			my @w = ($rstr);	
			foreach my $k (@keys){
				my $fmt = "%7.3f";
				$fmt = "%7.1f"  if($k eq "pop_100k");
				$fmt = "%9.2f"  if($k eq "nd_max");
				$fmt = "%11.2f" if($k eq "nc_max");
				push(@w, sprintf($fmt, $r->{$k}));
			}
			#$w[0] = "# $w[0]";
			print HTML &table(@w) . "\n";
		}
		print HTML "</tbody></table>\n";
		print HTML "<hr>\n";
	}
	print HTML "</body></html>\n";
	close(HTML);
}

sub	table
{
	return &_print_table("td", 'align="right"', @_);
}
sub	table_head
{
	return &_print_table("th", 'align="center"', @_);
}
sub	_print_table
{
	my ($tag, $sub, @data) = @_;
	
	my $d = shift(@data);
	my $s = "<tr><$tag align=\"left\">$d</$tag>";
	foreach my $d (@data){
		$s .= "<$tag $sub>$d</$tag>";
	}
	$s .= "</tr>";
	return $s;
}

#
#	CCSE
#
if($golist{"ccse-tgt"}){
	dp::set_dp_id("ccse-tgt $GKIND");
	&ccse("ccse-tgt");
}
if($golist{ccse}) {
	dp::set_dp_id("ccse $GKIND");
	&ccse("ccse");
}
if($golist{ccse_jp_term}){
	&ccse_jp_term("ccse_jp_term");
}

sub	ccse
{
	my ($param) = @_;
	@REG_INFO_LIST = ();
	dp::dp "CCSE\n";
	my $ccse_gp_list = [];
	my $ccse_rlavr_gp_list = [];
	my $ccse_pop_gp_list = [];
	my $gp_list = [];

	#
	#	Marge regional data of certain counties
	#
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);

	#	World Wide
	my $ww_cdp = $ccse_cdp->dup();
	$ww_cdp->calc_items("sum", 
				{"Province/State" => "", "Country/Region" => ""},				
				{"Province/State" => "null", "Country/Region" => "WorldWide"},
	);
	#$ww_cdp->dump({search_key => "WorldWide"});

	my $ww_deaths =  $death_cdp->dup();
	$ww_deaths->calc_items("sum", 
				{"Province/State" => "", "Country/Region" => ""},			
				{"Province/State" => "null", "Country/Region" => "WorldWide"},
	);

	foreach my $start_date (0, $RECENT, $RECENT_MONTH){
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defccse::CCSE_GRAPH, dsc => "World Wilde positive and deaths", start_date => $start_date, 
			ymin => 0, y2min => 0,
			ylabel => "positive", y2label => "deaths",
			graph_items => [
				{cdp => $ww_cdp,  item => {"Country/Region" => "WorldWide",}, static => "rlavr", graph_def => $line_thin},
				{cdp => $ww_deaths,  item => {"Country/Region" => "WorldWide"}, static => "rlavr", graph_def => $line_thick, axis => "y2"},
			],
		}
		));
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 3,		
			no_lank_label => 1,
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/worldwilde.html",
			alt_graph => "./worldwide" . "_rlavr.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $ccse_cdp->{src_info},
		}
	);
	#####

	foreach my $wcdp ($ccse_cdp, $death_cdp){
		foreach my $country ("Canada", "China", "Australia"){
			$wcdp->calc_items("sum", 
						{"Province/State" => "", "Country/Region" => $country},				# All Province/State with Canada, ["*","Canada",]
						{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
			);
		}
	}
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country

	my $graph_kind = $csv2graph::GRAPH_KIND;

	my $ccse_rlavr = $ccse_country->calc_rlavr($ccse_country);
	#$ccse_rlavr->dump({search_key => "Korea"});
	my $target_keys = [$ccse_rlavr->select_keys("", 0)];	# select data for target_keys
	my $sorted_keys = [$ccse_rlavr->sort_csv($ccse_rlavr->{csv_data}, $target_keys, $RECENT, 0)];
	my $target_region = ($param ne "ccse-tgt") ? $sorted_keys  : \@TARGET_REGION;
	my $endt = ($end_target <= 0) ? (min(scalar(@$target_region) -1, $CCSE_MAX_REGION)) : ($end_target - 1);
	$endt = $CCSE_MAX if($endt > $CCSE_MAX);
	#my $endt = ($end_target <= 0) ? $#TARGET_REGION : $end_target;
	dp::dp "####### " . $endt . "\n";
	foreach my $region (@$target_region[0..$endt]){
		$region =~ s/--.*//;
		dp::dp "rlavr: $region\n";
		foreach my $start_date(0, $RECENT, $RECENT_MONTH){
			push(@$ccse_gp_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date, 1, "raw")) if(!$GKIND || $GKIND eq "raw");	
			push(@$ccse_rlavr_gp_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date, 0, "rlavr")) if(!$GKIND || $GKIND eq "rlavr");
		}
	}

	#my $jp_pop_rlavr   = $jp_rlavr->calc_pop($jp_rlavr);
	#$sorted_keys = [$jp_pop_rlavr->sort_csv($jp_pop_rlavr->{csv_data}, $target_keys, $RECENT, 0)];

	if(!$GKIND || $GKIND eq "pop"){
		my $ccse_pop_rlavr   = $ccse_rlavr->calc_pop($ccse_rlavr);
		$sorted_keys = [$ccse_pop_rlavr->sort_csv($ccse_pop_rlavr->{csv_data}, $target_keys, $RECENT, 0)];
		$target_region = ($param ne "ccse-tgt") ? $sorted_keys  : \@TARGET_REGION;
		#dp::dp "####### " . $endt . "\n";
		dp::dp "pop:   " . join(",", (@$target_region[0..10])) . "\n";
		foreach my $region (@$target_region[0..$endt]){
			$region =~ s/--.*//;
			dp::dp "pop: $region\n";
			foreach my $start_date(0, $RECENT, $RECENT_MONTH){
				push(@$ccse_pop_gp_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date, 1, "pop"));
			}
		}
		csv2graph->gen_html_by_gp_list($ccse_pop_gp_list, {						# Generate HTML file with graphs
				row => 3,
				no_lank_label => 1,
				html_tilte => "COVID-19 related data visualizer ",
				src_url => "src_url",
				html_file => "$HTML_PATH/$param" . "_pop.html",
				alt_graph => "./$param" . "_rlavr.html",
				png_path => $PNG_PATH // "png_path",
				png_rel_path => $PNG_REL_PATH // "png_rel_path",
				data_source => $ccse_cdp->{src_info},
			}
		);

		my $outf = "$param" . "_ri_";
		my $reg_param = {graph_html => "./$param" . "_pop.html"};
		&gen_reginfo("$HTML_PATH/$outf", $reg_param, "nc_pop_last", "nc_pop_max");
		&gen_reginfo("$HTML_PATH/$outf", $reg_param, "nc_pop_max", "nc_pop_last");
		&gen_reginfo("$HTML_PATH/$outf", $reg_param, "nd_pop_last", "nd_pop_max");
		&gen_reginfo("$HTML_PATH/$outf", $reg_param, "nd_pop_max", "nd_pop_last");
		&gen_reginfo("$HTML_PATH/$outf", $reg_param, "drate_max");
		&gen_reginfo("$HTML_PATH/$outf", $reg_param, "drate_last");
		&gen_reginfo("$HTML_PATH/$outf", $reg_param, "nc_week_diff");
		&gen_reginfo("$HTML_PATH/$outf", $reg_param, "nd_week_diff");
		my $reg_param_th = {graph_html => ($reg_param->{graph_html}), thresh => $THRESH_POP_NC_LAST_WW, thresh_item => "nc_pop_last"};
		&gen_reginfo("$HTML_PATH/$outf" . "th_", $reg_param_th, "nc_week_diff", "nd_week_diff");


	}

	if(!$GKIND || $GKIND eq "raw"){
		csv2graph->gen_html_by_gp_list($ccse_gp_list, {						# Generate HTML file with graphs
				row => 3,
				no_lank_label => 1,
				html_tilte => "COVID-19 related data visualizer ",
				src_url => "src_url",
				html_file => "$HTML_PATH/$param.html",
				alt_graph => "./$param" . "_rlavr.html",
				png_path => $PNG_PATH // "png_path",
				png_rel_path => $PNG_REL_PATH // "png_rel_path",
				data_source => $ccse_cdp->{src_info},
			}
		);
	}

	if(!$GKIND || $GKIND eq "rlavr"){
		csv2graph->gen_html_by_gp_list($ccse_rlavr_gp_list, {						# Generate HTML file with graphs
				row => 3,
				no_lank_label => 1,
				html_tilte => "COVID-19 related data visualizer nc-nd ",
				src_url => "src_url",
				html_file => "$HTML_PATH/$param" . "_rlavr.html",
				alt_graph => "./$param" . "_pop.html",
				png_path => $PNG_PATH // "png_path",
				png_rel_path => $PNG_REL_PATH // "png_rel_path",
				data_source => $ccse_cdp->{src_info},
			}
		);


	}
}
######### try 
sub	ccse_jp_term
{
	my ($param) = @_;
	@REG_INFO_LIST = ();
	dp::dp "CCSE JP\n";
	my $ccse_gp_list = [];
	my $ccse_rlavr_gp_list = [];
	my $ccse_pop_gp_list = [];
	my $gp_list = [];

	#
	#	Marge regional data of certain counties
	#
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);

	foreach my $wcdp ($ccse_cdp, $death_cdp){
		foreach my $country ("Canada", "China", "Australia"){
			$wcdp->calc_items("sum", 
						{"Province/State" => "", "Country/Region" => $country},				# All Province/State with Canada, ["*","Canada",]
						{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
			);
		}
	}
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country

	my $ccse_japan = $ccse_cdp->reduce_cdp_target({"Country/Region" => "Japan"});	# Select Country
	my $death_japan = $death_cdp->reduce_cdp_target({"Country/Region" => "Japan"});	# Select Country
	my $ccse_rlavr = $ccse_japan->calc_rlavr($ccse_japan);

	my $m3 = 93;
	my $m15 = 35;
	foreach my $date("2020-01-23,$m3", "2020-04-01,$m3", "2020-07-01,m3", "2020-10-01,64", "2020-12-01,$m15", 
			"2021-01-01,$m15", "2021-02-01,$m15", "2021-03-01,$m15", "2021-04-01,$m15", "2021-05-01,$m15",
			"2021-06-01,$m15", "2021-07-01,$m15", "2021-08-01,$m15", "2021-09-01,$m15", "2021-10-01,$m15", "2021-11-01,2021-11-30"){
		my ($start_date, $end_date) = split(/,/, $date);
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $defccse::CCSE_GRAPH, dsc => "World Wild $start_date", start_date => $start_date, end_date => $end_date,
				ymin => 0, y2min => 0, 
				ylabel => "WW-Positve",  y2label => "Japan Positive",
				lank => [0,10],
				term_y_size => 400,
				graph_items => [
				{cdp => $ccse_country,  item => {}, static => "rlavr", graph_def => $line_thick},
				{cdp => $ccse_japan,  item => {}, static => "rlavr", graph_def => $line_thick_jp, axis => "y2"},
				],
			},
		));
		push(@$gp_list, &ccse_positive_death_ern($ccse_japan, $death_japan, "Japan", $start_date, 1, "pop", $end_date));
		#push(@$gp_list, &ccse_positive_death_ern($ccse_japan, $death_japan, "Japan", $start_date, 0, "rlavr", $end_date));
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			no_lank_label => 1,
			html_tilte => "COVID-19 related data visualizer WW 3months",
			src_url => "src_url",
			html_file => "$HTML_PATH/$param" . "_ww3m.html",
			alt_graph => "./$param" . "_ww_rlavr.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $ccse_cdp->{src_info},
		}
	);
#	foreach my $start_date("2020-01-23", "2020-04-01", "2020-07-01", "2020-10-01", "2021-01-01", "2021-04-01", "2021-07-01", "2021-10-01"){
#		push(@$ccse_pop_gp_list, &ccse_positive_death_ern($ccse_japan, $death_japan, "Japan", $start_date, 1, "pop", 93));
#	}
#	csv2graph->gen_html_by_gp_list($ccse_pop_gp_list, {						# Generate HTML file with graphs
#			row => 2,
#			no_lank_label => 1,
#			html_tilte => "COVID-19 related data visualizer 3months",
#			src_url => "src_url",
#			html_file => "$HTML_PATH/$param" . "_pop3m.html",
#			alt_graph => "./$param" . "_rlavr.html",
#			png_path => $PNG_PATH // "png_path",
#			png_rel_path => $PNG_REL_PATH // "png_rel_path",
#			data_source => $ccse_cdp->{src_info},
#		}
#	);


}



if($golist{usa}) {
	my $param = "USA";
	
	$gp_list = [];
	@REG_INFO_LIST = ();
	dp::dp "USA\n";
	my $TL = "TL";

	#
	#	Marge regional data of certain counties
	#
	my @CDPDS = (
		{dsc => "positive", cdp_def => $defccse::CCSE_US_CONF_DEF},
		{dsc => "death",    cdp_def => $defccse::CCSE_US_DEATHS_DEF},
	);
	my $src_info = $defccse::CCSE_US_CONF_DEF->{src_info};

	foreach my $cdpd (@CDPDS){
		my $dsc = $cdpd->{dsc};
		$cdpd->{cdpds} = {};
		my $cdpds = $cdpd->{cdpds};
		#$cdpd->{kind} = ["city", "state"];
		$cdpds->{city_raw} = csv2graph->new($cdpd->{cdp_def}); 						# Load Johns Hopkings University CCSE
		$cdpds->{city_raw}->load_csv({download => $DOWNLOAD});
		$cdpds->{city_rlavr} = $cdpds->{city_raw}->calc_rlavr();
		$cdpds->{city_pop}   = $cdpds->{city_rlavr}->calc_pop();

		my $cdpw = $cdpds->{city_raw}->dup();
		$cdpw->calc_items("sum", 
			{"Admin2" => "",  "Province_State" => ""},				# All Province/State with Canada, ["*","Canada",]
			{"Admin2" => $TL, "Province_State" => "="}				# total gos ["","Canada"] null = "", = keep
		);
		$cdpw->substr_keys("$TL-","");
		$cdpds->{state_raw}   = $cdpw->reduce_cdp_target({"Admin2" => $TL});
		$cdpds->{state_rlavr} = $cdpds->{state_raw}->calc_rlavr();
		$cdpds->{state_pop}   = $cdpds->{state_rlavr}->calc_pop();
	}
	my %dscs = ( raw => "raw", rlavr => "rlavr", pop => "pop");
	
	#my @CDPDS = ( {dsc => "positive", cdp => $defccse::CCSE_US_CONF_DEF},}
	foreach my $kind ("state", "city"){
		foreach my $cdpd (@CDPDS){
			my $dsc = $cdpd->{dsc};
			my $cdpds = $cdpd->{cdpds};
			foreach my $method ("raw", "rlavr", "pop"){
				my $cdp_key = "$kind" . "_" . $method;
				my $cdp = $cdpds->{$cdp_key} // "UNDEF";
				foreach my $start_date (0, $RECENT){
					my $dt = ($start_date == $RECENT) ? "(2 months)" : "";
					my $ymax_a = $cdp->max_val({start_date => $start_date});
					my $ymax = csvlib::calc_max2($ymax_a);			# try to set reasonable max 
					dp::dp "CDP: $dsc $cdp_key  [$cdp] $ymax_a $ymax\n";
					push(@$gp_list, csv2graph->csv2graph_list_gpmix(
						{gdp => $defccse::CCSE_GRAPH, dsc => "USA $kind $dsc $method $dt", start_date => $start_date, 
							#ymax => $ymax, y2max => $y2max, 
							ymin => 0, y2min => 0, # ymax => $ymax,
							ylabel => "$dsc", # y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
							#additional_plot => $additional_plot_item{ern}, 
							lank => [0,9],
							graph_items => [
							{cdp => $cdp,  item => {}, static => "", graph_def => $line_thick},
							#{cdp => $death_cdp, item => {Admin2 => ""}, static => "", axis => "y2", graph_def => $box_fill},
							],
						},
					));
				}
			}
		}
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			no_lank_label => 1,
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/$param" . "_area.html",
			#alt_graph => "./$param" . "_rlavr.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $src_info,
		}
	);
}
#
#	MHLW
#
if($golist{mhlw}) {
	dp::set_dp_id("mhlw");
	
	@$gp_list = ();
	# positive,  reqcare, deaths, severe
	my %cdp_raw = ();
	my @cdps = ();
	my $i = 0;

	my %date_info = (start_max => "0000-00-00", start_min => "9999-99-99",
					 end_max => "0000-00-00", end_min => "9999-99-99");
	my %mids = ();
	foreach my $p (@defmhlw::MHLW_DEFS){
		my $item = $p->{tag};
		dp::dp "CDP: " . join(",", $p->{tag}, $item) . "\n";

		my $cdp = csv2graph->new($p);
		$cdp_raw{$item} = $cdp;

		$cdp->load_csv({download => $DOWNLOAD, item => $item});
		#$cdp_rla{$item} = $cdp_raw{$item}->calc_rlavr();
		push(@cdps, $cdp_raw{$item});
		#$cdp->dump();
		#exit; #if($i++ > 1);

		my $dt = $cdp->{dates};
		my $sd = $cdp->{date_list}->[0];
		my $ed = $cdp->{date_list}->[$dt];
		$date_info{start_max} = $sd if($sd gt $date_info{start_max});
		$date_info{start_min} = $sd if($sd lt $date_info{start_min});
		$date_info{end_max} = $sd if($ed gt $date_info{end_max});
		$date_info{end_min} = $sd if($sd lt $date_info{end_min});
	}

	my $cdp = csv2graph->new($defmhlw::MHLW_TAG);
	$cdp = $cdp->marge_csv(@cdps);
	#$cdp->dump({search_key => "Tokyo", items => 10});
	my $cdp_rlavr = $cdp->calc_rlavr();

	#
	#	Calc percent, use marged data because of date gap
	#
	my $result_name = "percent";
	my @dm_key = ();
	my $item_sz = scalar(@{$cdp->{item_name_list}});
	for(my $i = 0; $i < $item_sz; $i++){
		push(@dm_key, "NaN");
	}

	$cdp->add_key_items([$config::MAIN_KEY, $result_name]);		# "item_name"
	my $csv_positive = $cdp_rlavr->{csv_data}->{"ALL-positive"};
	my $csv_tested = $cdp_rlavr->{csv_data}->{"tested-h"};
	my $master_key = join($cdp->{key_dlm}, $result_name);				# set key_name
	$cdp->add_record($master_key, [@dm_key, $result_name, $result_name],[$result_name]);		# add record without data 

	my $csv_pct = $cdp->{csv_data}->{$master_key};

	my $dates = $cdp_rlavr->{dates};
	#dp::dp "positive: (" . scalar(@$csv_positive) . ")" . join(",",  @$csv_positive) . "\n";
	#dp::dp "tested  : (" . scalar(@$csv_tested)   . ")" . join(",",  @$csv_tested) . "\n";
	for(my $i = 0; $i <= $dates; $i++){
		my $p =  $csv_positive->[$i] // 0;
		my $t = $csv_tested->[$i] // 999999;
		my $v = sprintf("%.3f", $p * 100 / $t);
		$csv_pct->[$i] = $v;
	}
	#$cdp->dump({search_key => "percent", lines => 10});

	#
	#	Japan all data
	#
	foreach my $start_date (0, $RECENT, $RECENT_MONTH){
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defmhlw::MHLW_GRAPH, dsc => "Japan PCR test results", start_date => $start_date, 
			ymin => 0, y2min => 0,y2max => 35,
			ylabel => "pcr_tested/positive", y2label => "positive rate(%)",
			term_y_size => $TERM_Y_SIZE,
			graph_items => [
				{cdp => $cdp,  item => {"tested-t" => "tested-t"}, static => "rlavr", graph_def => $box_fill},
				{cdp => $cdp,  item => {"pref-positive" => "ALL-positive"}, static => "rlavr", graph_def => $box_fill_solid},
				{cdp => $cdp,  item => {"percent" => "percent"}, static => "", graph_def => $line_thick, axis => "y2"},
				{cdp => $cdp,  item => {"tested-t" => "tested-t",}, static => "", graph_def => $line_thin_dot},
				{cdp => $cdp,  item => {"pref-positive" => "ALL-positive"}, static => "", graph_def => $line_thin_dot},

			#	{cdp => $cdp,  item => {"item" => "ALL",  "pref-t" => "Tested"}, static => "rlavr", graph_def => $box_fill},
			#	{cdp => $cdp,  item => {"item" => "ALL", "item-p" => "Positive"}, static => "rlavr", graph_def => $box_fill_solid},
			#	{cdp => $cdp,  item => {"item"}, static => "", graph_def => $line_thick, axis => "y2"},
			#	{cdp => $cdp,  item => {"Prefecture-t" => "ALL", "item-t" => "Tested"}, static => "", graph_def => $line_thin_dot},
			#	{cdp => $cdp,  item => {"Prefecture-p" => "ALL", "item-p" => "Positive"}, static => "", graph_def => $line_thin_dot},
			],
		}
		));
	}
if(0){			# from NHK,, 全国の県ごとのTOP10を出したい
	my $pref = "ALL";
	foreach my $start_date (0, $RECENT, $RECENT_MONTH){
		my $lank_width = 10;
		my $lank = 1;
		my $lank_max = 10;
		my $first_date = "2020-03-12";
		foreach my $item ("testedPositive", "deaths"){
			my $label = ($item eq "testedPositive") ? "positive" : "deaths";
				my $kind = $cdp->{kind};
				
				for($lank = 1; $lank < $lank_max; $lank += $lank_width){
					dp::dp "kind:$kind label:$label lank:$lank + $lank_width\n";
					my $le = $lank + $lank_width - 1;
					push(@$gp_list, csv2graph->csv2graph_list_gpmix(
					{gdp => $defnhk::DEF_GRAPH, dsc => "mhlw $item [$lank-$le] $kind rlavr" , start_date => $start_date, 
						ylabel => $label, y2label => $label,
						ymin => 0, y2min => 0,
						lank => [$lank,$le],
						graph_tag => "Japan $kind $label [$lank - " . ($lank + $lank_width -1) . "]",
						label_sub_from => '#.*', label_sub_to => '',	# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
						graph_items => [
							{cdp => $cdp, item => {"pref-positive" => "$pref-positive"}, static => "", graph_def => $line_thick,},
						],
					}));
				}
			}
		}
}

if(1){		# 0 for test
	my $pref = "ALL";
	foreach my $start_date (0, $RECENT, $RECENT_MONTH){
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defmhlw::MHLW_GRAPH, dsc => "Japan $pref hospitalized,severe and deaths", start_date => $start_date, 
			ymin => 0, y2min => 0,
			ylabel => "hospitalzed/servere", 
			graph_items => [
				{cdp => $cdp,  item => {"pref-severe" => "$pref-severe"}, static => "", graph_def => $box_fill, axis => "y2"},
				{cdp => $cdp,  item => {"pref-h" => "$pref-h", "kind-h" => "Inpatient"}, static => "", graph_def => $line_thick,},
				{cdp => $cdp,  item => {"pref-deaths" => "$pref-deaths"}, static => "rlavr", graph_def => $box_fill_solid, axis => "y2"},
				{cdp => $cdp,  item => {"pref-deaths" => "$pref-deaths"}, static => "", graph_def => $line_thin_dot, axis => "y2"},

				#{cdp => $cdp,  item => {"pref-s" => "$pref-s", "item-s" => "Severe"}, static => "", graph_def => $box_fill, axis => "y2"},
				#{cdp => $cdp,  item => {"pref-h" => "$pref-h", "item-h" => "Inpatient"}, static => "", graph_def => $line_thick,},
				#{cdp => $cdp,  item => {"pref-d" => "$pref-d", "item-d" => "Deaths"}, static => "rlavr", graph_def => $box_fill_solid, axis => "y2"},
				#{cdp => $cdp,  item => {"pref-d" => "$pref-d", "item-d" => "Deaths"}, static => "", graph_def => $line_thin_dot, axis => "y2"},
			],
		}
		));
	}

}

	#
	#	NHK - Tokyo
	#
	my $cdp_tko = csv2graph->new($deftkocsv::TKOCSV_DEF); 						# Load Johns Hopkings University CCSE
	$cdp_tko->load_csv({download => $DOWNLOAD});
	my $rlavr_tko = $cdp_tko->calc_rlavr();

	$rlavr_tko->calc_record({result => "#total_positive", op => ["pcr_positive", "+antigen_positive"]});
	$rlavr_tko->calc_record({result => "#total_tested", op => ["pcr_negative", "+antigen_negative", "+pcr_positive", "+antigen_positive"]});
	$rlavr_tko->calc_record({result => "#total_pcr", op => ["pcr_positive", "+pcr_negative"]});
	$rlavr_tko->calc_record({result => "#positive_percent", op => ["positive_rate", "*=100"], v => 0} );

	#$rlavr_tko->dump({search_key => "positive_percent"});
	#$rlavr_tko->dump({lines => 20});
	# $rlavr_tko->dump({items => 10, lines => 20});

	$cdp_tko->calc_record({result => "#total_positive", op => ["pcr_positive", "+antigen_positive"]});
	$cdp_tko->calc_record({result => "#total_tested", op => ["pcr_negative", "+antigen_negative", "+pcr_positive", "+antigen_positive"]});
	$cdp_tko->calc_record({result => "#total_pcr", op => ["pcr_positive", "+pcr_negative"]});
	$cdp_tko->calc_record({result => "#positive_percent", op => ["positive_rate", "*=100"]});

	foreach my $start_date (0, $RECENT, $RECENT_MONTH){
		my $box = (!($start_date =~ /[-+]?\W+$/) ||  $start_date >= 0) ? $box_fill : $box_fill_solid;
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $deftkocsv::TKOCSV_GRAPH, dsc => "Tokyo open Data tested", start_date => $start_date, 
			ylabel => "positive/tested", y2label => "positive rate(%)",
			ymin => 0, y2min => 0, y2max => 60,
			graph_items => [
				{cdp => $rlavr_tko,  item => {"item" => "total_tested",}, static => "", graph_def => $box_fill},
				{cdp => $rlavr_tko,  item => {"item" => "total_positive",}, static => "", graph_def => $box_fill_solid},
				{cdp => $rlavr_tko,  item => {"item" => "positive_percent",}, static => "", graph_def => $line_thick, axis => "y2"},

				{cdp => $cdp_tko  ,  item => {"item" => "total_tested",}, static => "", graph_def => $line_thin_dot},
				{cdp => $cdp_tko  ,  item => {"item" => "total_positive",}, static => "", graph_def => $line_thin_dot},
				{cdp => $cdp_tko  ,  item => {"item" => "positive_percent",}, static => "", graph_def => $line_thin_dot, axis => "y2"},
			],
		}));

	}

	#
	#	"pcr_positive", "antigen_positive", "pcr_negative", "antigen_negative", "inspected", "positive_rate",
	#			"positive_number", "hospitalized", "mid-modelate", "severe", "residential", "home","adjusting", "deaths", "discharged",
	foreach my $start_date (0, $RECENT){
		my $box = (!($start_date =~ /[-+]?\W+$/) || ($start_date >= 0)) ? $box_fill : $box_fill_solid;
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $deftkocsv::TKOCSV_GRAPH, dsc => "TKOCSV open Data hospitalized", start_date => $start_date, 
			ylabel => "confermed", y2label => "positive rate(%)",
			ymin => 0, y2min => 0,
			graph_items => [
				#{cdp => $cdp_tko  ,  item => {"item" => "severe",}, static => "", graph_def => $box_fill, axis => "y2",},
				{cdp => $cdp_tko  ,  item => {"item" => "hospitalized",}, static => "", graph_def => $line_thick},
				{cdp => $cdp_tko  ,  item => {"item" => "deaths",}, static => "rlavr", graph_def => $box_fill_solid, axis => "y2"},
				{cdp => $cdp_tko  ,  item => {"item" => "deaths",}, static => "", graph_def => $line_thin_dot, axis => "y2"},
				{cdp => $cdp_tko  ,  item => {"item" => "severe",}, static => "", graph_def => $line_thick, axis => "y2",},
				#{cdp => $cdp  ,  item => {"item" => "mid-modelate",}, static => "", graph_def => $line_thick},
			],
		}));
	}

	#
	#	"pcr_positive", "antigen_positive", "pcr_negative", "antigen_negative", "inspected", "positive_rate",
	#			"positive_number", "hospitalized", "mid-modelate", "severe", "residential", "home","adjusting", "deaths", "discharged",
	foreach my $start_date (0, $RECENT, $RECENT_MONTH){
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $deftkocsv::TKOCSV_GRAPH, dsc => "TKOCSV open Data hospitalized residential home", start_date => $start_date, 
			ylabel => "all data(no y2)", 
			ymin => 0, y2min => 0,
			graph_items => [
				{cdp => $cdp_tko  ,  item => {"item" => "hospitalized",}, static => "", graph_def => $line_thick},
				{cdp => $cdp_tko  ,  item => {"item" => "residential",}, static => "", graph_def => $line_thick},
				{cdp => $cdp_tko  ,  item => {"item" => "home",}, static => "", graph_def => $line_thick, axis => ""},
				{cdp => $cdp_tko  ,  item => {"item" => "adjusting",}, static => "", graph_def => $line_thick, axis => ""},
			],
		}));
	}

	#
	#	"pcr_positive", "antigen_positive", "pcr_negative", "antigen_negative", "inspected", "positive_rate",
	#			"positive_number", "hospitalized", "mid-modelate", "severe", "residential", "home","adjusting", "deaths", "discharged",
	#foreach my $start_date (0, $RECENT){
	#	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	#	{gdp => $deftkocsv::TKOCSV_GRAPH, dsc => "TKOCSV open Data hospitalized residential home y2", start_date => $start_date, 
	#		ylabel => "hospitalized/residential", y2label => "home",
	#		ymin => 0, y2min => 0,
	#		graph_items => [
	#			{cdp => $cdp_tko  ,  item => {"item" => "hospitalized",}, static => "", graph_def => $line_thick},
	#			{cdp => $cdp_tko  ,  item => {"item" => "residential",}, static => "", graph_def => $line_thick},
	#			{cdp => $cdp_tko  ,  item => {"item" => "home",}, static => "", graph_def => $line_thick, axis => "y2"},
	#		],
	#	}));
	#}


	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/mhlw.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp_tko->{src_info},
		}
	);
}

#
#
#
# if($golist{"mhlw"} || $golist{"mhlw-pref"}) 	# mhlw-pref
if($golist{"mhlw-pref"}){ 	# mhlw-pref
	dp::set_dp_id("mhlw-pref");
	dp::dp "-" x 40 . "\n";
	
	@$gp_list = ();
	# positive,  reqcare, deaths, severe
	my %cdp_raw = ();
	my @cdps = ();
	foreach my $p (@defmhlw::MHLW_DEFS){
		my $item = $p->{tag};
		dp::dp "CDP: " . join(",", $p->{tag}, $item) . "\n";

		$cdp_raw{$item} = csv2graph->new($p); 			# Load MHLW
		$cdp_raw{$item}->load_csv({download => $DOWNLOAD, item => $item});
		#$cdp_rla{$item} = $cdp_raw{$item}->calc_rlavr();
		push(@cdps, $cdp_raw{$item});
		#$cdp_raw{$item}->dump();
	}
	my $cdp = csv2graph->new($defmhlw::MHLW_TAG);
	$cdp = $cdp->marge_csv(@cdps);
	#$cdp->dump({search_key => "Tokyo", items => 10});
	my $cdp_r = $cdp->calc_rlavr();

	#
	#	Prefectures from MHLW
	#
	my $target_keys = [$cdp_r->select_keys({"kind-h" => "Inpatient"}, 0)];	# select data for target_keys
	my $sorted_keys = [$cdp->sort_csv($cdp_r->{csv_data}, $target_keys, $RECENT, 0)];
	my $target_region = $sorted_keys;
	#@$target_region = ("Tokyo", "Osaka", "Okinawa", "Hyogo");
	#dp::dp join(",", @$target_region) . "\n";
	my $end = scalar(@$target_region) - 1; 
	$end = $end_target if($end_target > 0 && $end > $end_target);

	my $gp_list_a = [];
if(1){
	foreach my $pref (@$target_region[0..$end]){
		$pref =~ s/#.*$//;
		$pref =~ s/-.*$//;
		next if($pref =~ /^ALL/);

		my $nc = 1000; #500; #350;
		my $ns = 5; # 3;
		my $nm = 2; #1.5;# 1; # 1 / 5;
		#dp::dp "SYNOMYM: $config::SYNONYM{$pref} \n";
		my $prefw = $pref;
		$prefw =~ s/-.*$//;
		$prefw = "Japan" if($prefw eq "ALL");
		my $population = $POP{$prefw} // $POP{$config::SYNONYM{$prefw}}// dp::ABORT "no POP data [$prefw]\n";
		#dp::dp "[" . $config::SYNONYM{$pref} // "UNDEF:$pref" . "]\n";
		my $pop_100k = $population / 100000;
		my $ymax = $nc * $pop_100k;
		$ymax = csvlib::calc_max2($ymax);			# try to set reasonable max 
		my $y2max = $ns * $pop_100k;
		$y2max = csvlib::calc_max2($y2max);			# try to set reasonable max 
		my $pop_disp = int(0.5 + $population / 10000);

		my $add_plot = &gen_pop_scale({pop_100k => $pop_100k, pop_max => ($y2max / $pop_100k), init_dlt => 1,
								lc => "navy", title_tag => 'Severe %.1f/100K', axis => "x1y2"});

		my $cdp_svr = $cdp->reduce_cdp_target({"pref-severe" => "$pref-severe"});
		my $sv_max = $cdp_svr->max_rlavr({start_date => 0});
		#dp::dp "Servere MAX: $sv_max";
		$sv_max = csvlib::calc_max2($sv_max);			# try to set reasonable max 
		my $add_plot_a = &gen_pop_scale({pop_100k => $pop_100k, pop_max => ($sv_max / $pop_100k), init_dlt => 1,
								lc => "navy", title_tag => 'Severe %.1f/100K', axis => "x1y2"});
		foreach my $start_date (0, $RECENT){
			my $ymaxw = ($start_date eq "0") ? $ymax : ($ymax * $nm);
			my $y2maxw = ($start_date eq "0") ? $y2max : ($y2max * $nm);
			dp::dp "--- ymax: $ymaxw, $y2maxw\n";
			my @gpd =  csv2graph->csv2graph_list_gpmix(
			{gdp => $defmhlw::MHLW_GRAPH, dsc => "$pref hospitalized,severe and deaths", sub_dsc => "[nc:$nc,ns:$ns] $pop_disp*10K", start_date => $start_date, 
				ymin => 0, y2min => 0, ymax => $ymaxw, y2max => $y2maxw,
				ylabel => "hospitalzed/servere", 
				dditional_plot => $add_plot,
				graph_items => [
					{cdp => $cdp,   item => {"pref-severe" => "$pref-severe"}, static => "", graph_def => $box_fill, axis => "y2"},
					{cdp => $cdp_r, item => {"pref-positive" => "$pref-positive"}, static => "", graph_def => $line_thick,},
					{cdp => $cdp,   item => {"pref-h" => "$pref-h", "kind-h" => "Inpatient"}, static => "", graph_def => $line_thick,},
					{cdp => $cdp_r, item => {"pref-deaths" => "$pref-deaths"}, static => "", graph_def => $box_fill_solid, axis => "y2"},
					{cdp => $cdp,   item => {"pref-deaths" => "$pref-deaths"}, static => "", graph_def => $line_thin_dot, axis => "y2"},

					#{cdp => $cdp,   item => {"pref-s" => "$pref-s", "item-s" => "Severe"}, static => "", graph_def => $box_fill, axis => "y2"},
					#{cdp => $cdp_r, item => {"pref-p" => "$pref-p", "item-p" => "Positive"}, static => "", graph_def => $line_thick,},
					#{cdp => $cdp,   item => {"Prefecture-h" => "$pref", "item-h" => "Inpatient"}, static => "", graph_def => $line_thick,},
					#{cdp => $cdp_r, item => {"Prefecture-d" => "$pref", "item-d" => "Deaths"}, static => "", graph_def => $box_fill_solid, axis => "y2"},
					#{cdp => $cdp,   item => {"Prefecture-d" => "$pref", "item-d" => "Deaths"}, static => "", graph_def => $line_thin_dot, axis => "y2"},

				],
			}
			);
			push(@$gp_list, @gpd);
if(0){
			# &set_list($PREF_LIST, $gpd, $pref, "hospitalaized", "raw", $start_date);
			@gpd = csv2graph->csv2graph_list_gpmix(
			{gdp => $defmhlw::MHLW_GRAPH, dsc => "$pref hospitalized,severe and deaths severe", sub_dsc => "$pop_disp*10K", start_date => $start_date, 
				ymin => 0, y2min => 0, y2max => $sv_max,
				ylabel => "hospitalzed/servere", 
				additional_plot => $add_plot_a,
				graph_items => [
					{cdp => $cdp,   item => {"pref-severe" => "$pref-severe",}, static => "", graph_def => $box_fill, axis => "y2"},
					#{cdp => $cdp, item => {"Prefecture-p" => "$pref", "item-p" => "Positive"}, static => "rlavr", graph_def => $line_thick,},
					{cdp => $cdp_r, item => {"pref-positive" => "$pref-positive", }, static => "", graph_def => $line_thick,},
					{cdp => $cdp,   item => {"pref-h" => "$pref-h", "kind-h" => "Inpatient"}, static => "", graph_def => $line_thick,},
					#{cdp => $cdp, item => {"Prefecture-d" => "$pref", "item-d" => "Deaths"}, static => "rlavr", graph_def => $box_fill_solid, axis => "y2"},
					{cdp => $cdp_r, item => {"pref-deaths" => "$pref-deaths",}, static => "", graph_def => $box_fill_solid, axis => "y2"},
					{cdp => $cdp,   item => {"pref-deaths" => "$pref-deaths",}, static => "", graph_def => $line_thin_dot, axis => "y2"},
				],
			}
			);
			push(@$gp_list, @gpd);
}
			# &set_list($PREF_LIST, $gpd, $pref, "hospitalaized", "pop", $start_date);
		}
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/mhlw_pref.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}
if(1) {			# Nationwide lanking
	foreach my $item ("positive", "deaths"){
		my $cdp = &mhlw_cdp($item);
		if(!$cdp){
			dp::dp "no data at MHLW_DEFS($item)\n";
			next;
		}
		$cdp_r = $cdp->calc_rlavr();

		foreach my $kind ("rlavr", "pop"){
			my $cdp = $cdp_r;
			if($kind eq "pop"){
				$cdp = $cdp_r->calc_pop();
			}
			#$cdp->dump();
			foreach my $start_date (0, $RECENT, -31){ #$RECENT_MONTH
				my @gpd = csv2graph->csv2graph_list_gpmix(
				{gdp => $defmhlw::MHLW_GRAPH, dsc => "$item positive lank[1,10]($kind)", sub_dsc => "", start_date => $start_date, 
					ymin => 0, y2min => 0, #ymax => $ymaxw, y2max => $y2maxw,
					ylabel => "$item", 
					lank => [2,11],
					#dditional_plot => $add_plot,
					graph_items => [
						{cdp => $cdp, item => {}, static => "", graph_def => $line_thick,},
					],
				});
				push(@$gp_list, @gpd);
			}
		}
	}

	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 3,
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/mhlw_pref_lank.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}


sub	mhlw_cdp
{
	my ($item) = @_;

	my $itemp = "";
	foreach my $p (@defmhlw::MHLW_DEFS){
		if($p->{tag} eq $item){
			my $cdp = csv2graph->new($p);
			$cdp->load_csv({download => $DOWNLOAD, item => $item});
			return $cdp;
		}
	}
	return "";
}
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

#
#	NHK
#
if($golist{nhk}){
	dp::set_dp_id("nhk");
	@$gp_list = ();

	my $cdp = csv2graph->new($defnhk::CDP); 						# Load Johns Hopkings University CCSE
	$cdp->load_csv({download => $DOWNLOAD});
	my $pop_raw_cdp = $cdp->calc_pop();
	my $rlavr_cdp = $cdp->calc_rlavr();
	my $pop_cdp = $rlavr_cdp->calc_pop();

	my $cdp_list = [{kind => "", rlavr => $rlavr_cdp, raw => $cdp},
					{kind => "POP", rlavr => $pop_cdp,  raw => $pop_raw_cdp},
					];

	my $lank_width = 10;
	my $lank = 1;
	my $lank_max = 10;
	my $first_date = "2020-03-12";
	foreach my $item ("testedPositive", "deaths"){
		my $label = ($item eq "testedPositive") ? "positive" : "deaths";
		foreach my $tgcdp (@$cdp_list){
			my $kind = $tgcdp->{kind};
			
			for($lank = 1; $lank < $lank_max; $lank += $lank_width){
				dp::dp "kind:$kind label:$label lank:$lank + $lank_width\n";
				my $le = $lank + $lank_width - 1;
				foreach my $start_date ($first_date, -31){
					push(@$gp_list, csv2graph->csv2graph_list_gpmix(
					{gdp => $defnhk::DEF_GRAPH, dsc => "NHK open Data $item [$lank-$le] $kind rlavr" , start_date => $start_date, 
						ylabel => $label, y2label => $label,
						ymin => 0, y2min => 0,
						lank => [$lank,$le],
						graph_tag => "Japan $kind $label [$lank - " . ($lank + $lank_width -1) . "]",
						label_sub_from => '#.*', label_sub_to => '',	# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
						graph_items => [
							{cdp => $tgcdp->{rlavr}, item => {"item" => $item,}, static => "", graph_def => $line_thick},
						],
					}));
				}
				foreach my $start_date ($first_date, -31){
					push(@$gp_list, csv2graph->csv2graph_list_gpmix(
					{gdp => $defnhk::DEF_GRAPH, dsc => "NHK open Data $item [$lank-$le] $kind " , start_date => $start_date, 
						ylabel => $label, y2label => $label,
						ymin => 0, y2min => 0,
						lank => [$lank,$le],
						graph_tag => "Japan $kind $label [$lank - " . ($lank + $lank_width -1) . "]",
						label_sub_from => '#.*', label_sub_to => '',	# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
						graph_items => [
							{cdp => $tgcdp->{raw}, item => {"item" => "testedPositive",}, static => "", graph_def => $line_thick},
						],
					}));
				}
			}
		}
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 4,
			html_tilte => "COVID-19 related data visualizer HNK ",
			src_url => "src_url",
			html_file => "$HTML_PATH/nhk_jp.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}

#
#	tokyo age
#
if($golist{"tko-age"}){
	dp::set_dp_id("tko-age");
	my $BASE_DIR = "$config::WIN_PATH/tokyo-ku";
	@$gp_list = ();
	foreach my $m (1..9){
		dp::dp "------- $m \n";
		my $url = sprintf("https://www.metro.tokyo.lg.jp/tosei/hodohappyo/press/2022/%02d/index.html", $m);
		my $indexf = sprintf("$BASE_DIR/2022%02dindex.html", $m);
		tkopdf::download({url => $url, indexf => $indexf});
		tkopdf::getpdfdata($indexf);
	}
	tkopdf::pdf2csv();
	exit;

	tkopdf::download();
	tkopdf::getpdfdata();
	exit;

if(0){
	my $cdp = csv2graph->new($defnhk::CDP); 						# Load Johns Hopkings University CCSE
	$cdp->load_csv({download => $DOWNLOAD});
	my $pop_raw_cdp = $cdp->calc_pop();
	my $rlavr_cdp = $cdp->calc_rlavr();
	my $pop_cdp = $rlavr_cdp->calc_pop();

	my $cdp_list = [{kind => "", rlavr => $rlavr_cdp, raw => $cdp},
					{kind => "POP", rlavr => $pop_cdp,  raw => $pop_raw_cdp},
					];

	my $lank_width = 10;
	my $lank = 1;
	my $lank_max = 10;
	my $first_date = "2020-03-12";
	foreach my $item ("testedPositive", "deaths"){
		my $label = ($item eq "testedPositive") ? "positive" : "deaths";
		foreach my $tgcdp (@$cdp_list){
			my $kind = $tgcdp->{kind};
			
			for($lank = 1; $lank < $lank_max; $lank += $lank_width){
				dp::dp "kind:$kind label:$label lank:$lank + $lank_width\n";
				my $le = $lank + $lank_width - 1;
				foreach my $start_date ($first_date, -31){
					push(@$gp_list, csv2graph->csv2graph_list_gpmix(
					{gdp => $defnhk::DEF_GRAPH, dsc => "NHK open Data $item [$lank-$le] $kind rlavr" , start_date => $start_date, 
						ylabel => $label, y2label => $label,
						ymin => 0, y2min => 0,
						lank => [$lank,$le],
						graph_tag => "Japan $kind $label [$lank - " . ($lank + $lank_width -1) . "]",
						label_sub_from => '#.*', label_sub_to => '',	# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
						graph_items => [
							{cdp => $tgcdp->{rlavr}, item => {"item" => $item,}, static => "", graph_def => $line_thick},
						],
					}));
				}
			}
		}
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 4,
			html_tilte => "COVID-19 related data visualizer HNK ",
			src_url => "src_url",
			html_file => "$HTML_PATH/nhk_jp.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}
}
#
#	Prefecture ERN
#
if($golist{"pref-ern"}){
	dp::set_dp_id("pref-ern");
	@$gp_list = ();

	#my $item = "testedPositive";
	#my $cdp = csv2graph->new($defnhk::CDP); 						# Load Johns Hopkings University CCSE
	#$cdp->load_csv({download => $DOWNLOAD});
	my $item = "positive";
	my $cdp = &mhlw_cdp("positive");
	dp::ABORT "no data at MHLW_DEFS(positive)\n" if(!$cdp);
	my $target_keys = [$cdp->select_keys("", 0)];	# select data for target_keys
	my $sorted_keys = [$cdp->sort_csv($cdp->{csv_data}, $target_keys, $RECENT, 0)];

	#my $ern_cdp_w = $cdp->reduce_cdp_target({item => "testedPositive"});
	#my $ern_cdp = $ern_cdp_w->calc_ern();
	my $ern_cdp = $cdp->calc_ern();
	#$ern_cdp->rename_key($key, "$region-ern");
	#$ern_cdp->dump({lines => 20});
	#exit;

	my $first_date = "2020-03-12";
	my $end = scalar(@$sorted_keys) -1;

	my $additional_plot = $additional_plot_item{ern}; 
	$additional_plot =~ s/y2/y1/;
	my $label = "ern";
	foreach my $pref (@$sorted_keys[0..$end]) { # "東京都")		data is mainkey ex.東京#testedPositive--conf-rlavr
		$pref =~ s/#.*$//;
		foreach my $start_date ($first_date, $RECENT_ERN){
			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $defnhk::DEF_GRAPH, dsc => "MHLW open Data $pref ern " , start_date => $start_date, 
				ylabel => $label,
				ymin => 0, ymax => 3,
				graph_tag => "ERN  $label",
				label_sub_from => '#.*', label_sub_to => '',	# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
				additional_plot => $additional_plot, 
				graph_items => [
					{cdp => $ern_cdp, item => {pref => "$pref"}, static => "", graph_def => $line_thick},
				],
			}));
		}
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			html_tilte => "COVID-19 related data visualizer HNK ",
			src_url => "src_url",
			html_file => "$HTML_PATH/pref_ern.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}

#
#	CCSE ERN
#
if($golist{"ccse-ern"}){
	dp::set_dp_id("ccse-ern");
	@$gp_list = ();

	my $cdp_w = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$cdp_w->load_csv($defccse::CCSE_CONF_DEF);
	my $cdp = $cdp_w->dup();
	foreach my $country ("Canada", "China", "Australia"){
		$cdp->calc_items("sum", 
					{"Province/State" => "", "Country/Region" => $country},		
					{"Province/State" => "null", "Country/Region" => "="}	
		);
	}
	#$ww_cdp->dump({search_key => "WorldWide"});
	my $item = "testedPositive";

	my $target_keys = [$cdp->select_keys("", 0)];	# select data for target_keys
	my $sorted_keys = [$cdp->sort_csv($cdp->{csv_data}, $target_keys, $RECENT, 0)];
	my $ern_cdp = $cdp->calc_ern();
	$ern_cdp->dump();

	my $first_date = "2020-03-12";
	my $end = 10; # scalar(@$sorted_keys);

	my $additional_plot = $additional_plot_item{ern}; 
	$additional_plot =~ s/y2/y1/;
	my $label = "ern";
	my $jp = "Japan";
	foreach my $region ($jp, @$sorted_keys[0..$end]) { #
		#dp::dp "[$region]\n";
		$region =~ s/-.*$//;
		my $ccse_reg = $region;
		$ccse_reg = "Taiwan*" if($region eq "Taiwan");
		$ccse_reg = "Korea-South" if($region eq "South Korea" || $region eq "Korea");
		$ccse_reg = "US" if($region eq "United States");
		dp::dp "[$region]\n";
		foreach my $start_date ($first_date, $RECENT_ERN){
			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $defccse::CCSE_GRAPH, dsc => "John hopkings ccse $region ern " , start_date => $start_date, 
				ylabel => $label,
				ymin => 0, ymax => 3,
				graph_tag => "ERN  $label",
				label_sub_from => '#.*', label_sub_to => '',	# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
				additional_plot => $additional_plot, 
				graph_items => [
					{cdp => $ern_cdp, item => {"Country/Region" => $ccse_reg}, static => "", graph_def => $line_thick},
				],
			}));
		}
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			html_tilte => "COVID-19 related data visualizer HNK ",
			src_url => "src_url",
			html_file => "$HTML_PATH/ccse_ern.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}


if($golist{"ccse-order"}){
	dp::set_dp_id("ccse-ern");
	@$gp_list = ();
	my $pos = "positive";
	my $deth = "deaths";
	my $cdp = {$pos => {}, $deth => {}};

	$cdp->{$pos}->{org} = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$cdp->{$pos}->{org}->load_csv($defccse::CCSE_CONF_DEF);
	$cdp->{$deth}->{org} = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$cdp->{$deth}->{org}->load_csv($defccse::CCSE_DEATHS_DEF);
	$cdp->{$pos}->{pop}   = $cdp->{$pos}->{org}->calc_pop($cdp->{$pos}->{org});
	foreach my $kind ($pos, $deth){
		foreach my $country ("Canada", "China", "Australia"){
			$cdp->{$kind}->{org}->calc_items("sum", 
						{"Province/State" => "", "Country/Region" => $country},		
						{"Province/State" => "null", "Country/Region" => "="}	
			);
		}
		#$cdp->{$kind}->{org}->calc_items("sum", 
		#			{"Province/State" => "", "Country/Region" => ""},				
		#			{"Province/State" => "null", "Country/Region" => "WorldWide"},
		#);
		$cdp->{$kind}->{rlavr} = $cdp->{$kind}->{org}->calc_rlavr();
		my $target_keys = [$cdp->{$kind}->{rlavr}->select_keys("", 0)];	# select data for target_keys
		$cdp->{$kind}->{sorted} = [$cdp->{$kind}->{org}->sort_csv($cdp->{$kind}->{org}->{csv_data}, $target_keys, $RECENT, 0)];
		$cdp->{$kind}->{pop}   = $cdp->{$kind}->{rlavr}->calc_pop($cdp->{$kind}->{rlavr});
	}
	dp::dp "##############\n";

	my $first_date = "2020-03-12";
	my $lank = 1;
	my $lank_width = 10;
	my $end = $lank_width; # scalar(@{$cdp->{$pos}->{sorted}});
	foreach my $kind ($pos, $deth){
			foreach my $kk ("rlavr", "pop"){
				foreach my $start_date ($first_date, $RECENT_2MONTH){
					push(@$gp_list, csv2graph->csv2graph_list_gpmix(
					{gdp => $defccse::CCSE_GRAPH, dsc => "John hopkings ccse Japan $kind $kk  " , 
						start_date => $start_date, 
						ylabel => $kind,
						#ymin => 0, ymax => 3,
						graph_tag => "CCSE  $kind",
						label_sub_from => '#.*', label_sub_to => '',# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
						graph_items => [
							{cdp => $cdp->{$kind}->{$kk}, item => {"Province/State" => "null", "Country/Region" => "Japan"}, static => "", graph_def => $line_thick},
					],
					}));
				}
			}
	}

	$lank = 1;
	$end = $lank_width; # scalar(@{$cdp->{$pos}->{sorted}});
	foreach my $kind ($pos, $deth){
		for(my $l = $lank; $l < $end; $l += $lank_width){
			my $le = $l + $lank_width - 1;
			dp::dp "[$l - $le]\n";
			foreach my $kk ("rlavr", "pop"){
				foreach my $start_date ($first_date, $RECENT_2MONTH){
					push(@$gp_list, csv2graph->csv2graph_list_gpmix(
					{gdp => $defccse::CCSE_GRAPH, dsc => "John hopkings ccse $kind $kk [$l - $le] " , 
						start_date => $start_date, 
						ylabel => $kind,
						#ymin => 0, ymax => 3,
						graph_tag => "CCSE  $kind",
						label_sub_from => '#.*', label_sub_to => '',# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
						lank => [$l,$le],
						graph_items => [
							{cdp => $cdp->{$kind}->{$kk}, item => {}, static => "", graph_def => $line_thick},
					],
					}));
				}
			}
		}

	}

	#dp::dp "##############\n";
	#
	#	Europe
	#
	foreach my $kind ($pos, $deth){
		foreach my $kk ("rlavr", "pop"){
			dp::dp "$kind $kk\n";
			$lank = 0;
			my $target_cdp = $cdp->{$kind}->{$kk};
			my $target_list = [];
			foreach my $region (@{$cdp->{$kind}->{sorted}}){
				last if($lank > $lank_width);

				$region =~ s/-.*$//;
				foreach my $r (@TARGET_EU){
					if($r eq $region){
						#dp::dp ">> $lank [$r][$region]\n";
						push(@$target_list, 
							{cdp => $target_cdp, item => {"Province/State" => "null", "Country/Region" => $region}, 
								static => "", graph_def => $line_thick}
						);
						$lank++;
						last;
					}
				}
			}

			#dp::dp "target_size: " . scalar(@$target_list) . "\n";
			foreach my $start_date ($first_date, $RECENT_2MONTH){
				push(@$gp_list, csv2graph->csv2graph_list_gpmix(
				{gdp => $defccse::CCSE_GRAPH, dsc => "John hopkings ccse EU $kind $kk [1 - $lank_width] " , 
					start_date => $start_date, 
					ylabel => $kind,
					#ymin => 0, ymax => 3,
					graph_tag => "CCSE  $kind",
					label_sub_from => '#.*', label_sub_to => '',# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
					#lank => [$l,$le],
					graph_items => $target_list,
				}));
			}
			dp::dp "##############\n";
		}
	}
	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			html_tilte => "COVID-19 related data visualizer HNK ",
			src_url => "src_url",
			html_file => "$HTML_PATH/ccse_order.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}

sub	ccse_region
{
	my ($ccse_reg) = @_;
	$ccse_reg = "Taiwan*" if($ccse_reg eq "Taiwan");
	$ccse_reg = "Korea-South" if($ccse_reg eq "South Korea" || $ccse_reg eq "Korea");
	$ccse_reg = "US" if($ccse_reg eq "United States");
	return $ccse_reg;
}

#
#	"date":"2021-07-06","prefecture":"47","gender":"U","age":"UNK","medical_worker":false,"status":2,"count":5
#	"date":"2021-07-06","prefecture":"47","age":"UNK","status":2,"count":5
#
#
if($golist{jpvac})
{
	dp::set_dp_id("jpvac");
	my $jp_cdp = csv2graph->new($defjapan::JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($defjapan::JAPAN_DEF);
#	$jp_cdp->calc_items("sum", 
#		{prefectureNameJ => "", },						# All Prefecture
#		#{year => "=",month => "=",date => "=" ,prefectureNameJ => "Japan",prefectureNameE => "Japan",item => "="}
#		{prefectureNameJ => "Japan"},
#	);
#	$jp_cdp->dump({search_key => "Japan"});
#	exit;

	my $jp_rlavr = $jp_cdp->calc_rlavr();

	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL", "Country/Region" => "Japan"});	# Select Country
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL", "Country/Region" => "Japan"});	# Select Country
	my $positive_rlavr = $ccse_country->calc_rlavr();
	my $death_rlavr = $death_country->calc_rlavr();

	my $cdp_def = $defjpvac::VACCINE_DEF;
	my $cdp = csv2graph->new($cdp_def); 						# Load Johns Hopkings University CCSE
	$cdp->load_csv({download => $DOWNLOAD});

###############
if(0){
	$cdp->calc_items("sum", 
		{prefecture => "", },				
		{prefecture => "JAPAN",age => "=", status => "="}			# 
	);
	$cdp->dump({search_key => "JAPAN"});

	my $pop_jp = $POP{Japan} / 100;
	foreach my $age ("all", "le64", "ge65"){
		foreach my $st ("any", "1", "2"){
			#dp::dp join(",", "Japan#$age#$st"."p", "#Japan#$age#$st", "/=$pop_jp") . "\n";
			$cdp->calc_record({dlm => "#", result => "#Japan#$age#$st"."-C",  op => ["#Japan#$age#$st"], cumulative => 1});		#
		#	$cdp->dump({search_key => ("$age$st")});
		#	$cdp->calc_record({dlm => "#", result => "#Japan#$age#$st"."-CP", op => ["#Japan#$age#$st"."-C", "/=$pop_jp"]});		#

			my $atag = "Japan-$age";
			my $pop_age = $POP{$atag} // dp::ABORT "No POP data for [$atag]";
			$pop_age /= 100;
			dp::dp "$atag : " . $pop_age . "\n";
			$cdp->calc_record({dlm => "#", result => "#Japan#$age#$st"."-CP", op => ["#Japan#$age#$st"."-C", "/=$pop_age"]});		# 
			$cdp->dump({search_key => "$age#$st"});
		}
	}
	exit;
}
##############
	my $death_max = $death_rlavr->max_val({start_date => "2021-04-13"}) / 100;
	$death_rlavr->calc_record({dlm => "#", result => "##Japan--death_p#", op => ["Japan--death", "/=$death_max"]});			# daily to cumulative
	#$death_rlavr->dump({items => 100});
	#dp::dp "key_order " . join(",", @{$death_rlavr->{keys}}) . "\n";
	
	#$cdp->dump({search_key => "Japan#all#any-c", items => 100});
	#$cdp->dump({lines => 1000});

	#
	#	axis: for each 20%
	#
	my @adp = ();
	my $pct_gap = 10;
	for(my $i = 1; ($i * $pct_gap) < 100; $i++){
		my $pct = $i * $pct_gap; 
		my $dt = (($pct % 20) == 0 ) ? "lc 'blue' dt (3,7)" : "lc 'blue' dt (2,8)";
		#my $dt = "lc 'red' dt (6,4)";
		my $title = "title '$pct%'";
		push(@adp, "$pct axis x1y2 with lines notitle lw 1 $dt");
	}
	my $percent_axis = join(",\\\n", @adp);

	my $start_date = "2021-04-13";
	@$gp_list = ();

	#
	#	calculation
	#
#	my @pref_list = ("東京都","埼玉県","神奈川県", "千葉県", "京都府", "大阪府", "兵庫県","奈良県","沖縄県");
	my @pref_list = (1..47);
	my $AREA_CODE = {};
	defjpvac::load_area_code($AREA_CODE);
if(0){			# use calc_record, instead of data calucated in download	CP -> cp
	foreach my $pref (@pref_list[0..47]){ #(1..47){
		if($pref =~ /^\d+$/){
			my $pn = sprintf("%02d", $pref);
			dp::dp "<<$pn>>\n";
			$pref = $AREA_CODE->{$pn};
		}
		else {
			$pref = "Japan";			# #### JAPAN for calc_record
		}

		foreach my $age ("all", "le64", "ge65"){
			my $atag = "$pref" . (($age eq "all") ? "" : "-$age");
			foreach my $st ("any", "1", "2"){
				my $pop_age = $POP{$atag} // dp::ABORT "No POP data for [$atag]";
				$pop_age /= 100;
				dp::dp "$atag : " . $pop_age . "\n";
				$cdp->calc_record({dlm => "#", result => ("#$pref#$age#$st"."-C"),  op => ["#$pref#$age#$st"], cumulative => 1});		#
				$cdp->calc_record({dlm => "#", result => ("#$pref#$age#$st"."-CP"), op => ["#$pref#$age#$st"."-C", "/=$pop_age"]});		# 
				# $cdp->dump({search_key => "#$pref#$age#$st"});
			}
		}
	}
}
	#
	#	Lank of vaccinated pref
	#
if(0){
	foreach my $ag ("ge65", "all"){
		foreach my $st ("1-cp", "2-cp"){ # "1-cp", "2-cp"){
			my $tg_cdp = $cdp->reduce_cdp_target({age => $ag, status => $st});
			my $lank_width = 48 / 2;
			for(my $lank = 1; $lank <= 48; $lank += $lank_width){
				my $le = $lank + $lank_width - 1;
				$le = 47 if($le > 48);
				push(@$gp_list, csv2graph->csv2graph_list_gpmix(
				{gdp => $defjpvac::VACCINE_GRAPH, dsc => "Japan Vaccine($ag,$st) $lank-$le (rlavr 7)", start_date => $start_date, 
					graph_tag => "Japan Vaccinated",
					ylabel => "Vaccinated (%)", y2label => "Vaccinated (%)", 
					ymin => 0, ymax => 100, y2min => 0, y2max => 100,
					additional_plot => $percent_axis,
					#label_sub_from => "#$ag" . '.*', label_sub_to => '',	# change label 
					lank => [$lank, $le],
					sort_start => -2, sort_end => -1,
					term_y_size => 400,
					graph_items => [
						{cdp => $tg_cdp,  item => {age => $ag, status => $st}, static => "", graph_def => $line_thin},
					],
				}));
			}
		}
	}
}
	##### Japan
	my $pref = "Japan";
	my $rlavr = $cdp->calc_rlavr();
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defjpvac::VACCINE_GRAPH, dsc => "Japan Vaccine(over 65), Positive and Deaths(rlavr 7)", start_date => $start_date, 
		ylabel => "confermed", y2label => "vaccine rate(%) and deaths/max(%)",
		ymin => 0, y2min => 0,
		additional_plot => $percent_axis,
		graph_items => [
			{cdp => $cdp,  item => {prefecture => $pref, age => "ge65", status => "1-cp"}, static => "", graph_def => $line_thick, axis => "y2"},
			{cdp => $cdp,  item => {prefecture => $pref, age => "ge65", status => "2-cp"}, static => "", graph_def => $line_thick, axis => "y2"},
			{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "1-cp"}, static => "", graph_def => $line_thick_dot, axis => "y2"},
			{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "2-cp"}, static => "", graph_def => $line_thick_dot, axis => "y2"},
			#{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "any-cp"}, static => "", graph_def => $box_fill_solid, axis => "y2"},
			{cdp => $death_rlavr,  item => {"Country/Region" => "Japan--death_p"}, static => "", graph_def => "$line_thin_dot lc rgb 'gray20'", axis => "y2"},
			{cdp => $positive_rlavr,  item => {}, static => "", graph_def => $line_thin_dot},
		],
	}));

#	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
#	{gdp => $defjpvac::VACCINE_GRAPH, dsc => "Japan Vaccine(all age), Positive and Deaths(rlavr 7)", start_date => $start_date, 
#		ylabel => "confermed", y2label => "vaccine rate(%) and deaths/max(%)",
#		ymin => 0, y2min => 0,
#		additional_plot => $percent_axis,
#		graph_items => [
#			{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "1-cp"}, static => "", graph_def => $box_fill, axis => "y2"},
#			{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "2-cp"}, static => "", graph_def => $box_fill, axis => "y2"},
#			{cdp => $positive_rlavr,  item => {}, static => "", graph_def => $line_thick},
#			{cdp => $death_rlavr,  item => {"Country/Region" => "Japan--death_p"}, static => "", graph_def => $line_thick, axis => "y2"},
#		],
#	}));

  
	my $et = ($end_target > 0 && $end_target <= $#pref_list) ? $end_target : $#pref_list;
	foreach my $pref (@pref_list[0..$et]){ #(1..47){
		if($pref =~ /^\d+$/){
			my $pn = sprintf("%02d", $pref);
			#dp::dp "<<$pn>>\n";
			$pref = $AREA_CODE->{$pn};
		}
		else {
			$pref = "Japan";
		}
		my $pop_pref = $POP{$pref} / 100;
		dp::dp "[$pref:$pop_pref]\n";
#		foreach my $age ("all", "le64", "ge65"){
#			foreach my $st ("any-c", "2-c"){
#				#dp::dp join(",", "Japan#$age#$st"."p", "#$pref#$age#$st", "/=$pop_jp") . "\n";
#				$cdp->calc_record({dlm => "#", result => "#$pref#$age#$st"."p", op => ["#$pref#$age#$st", "/=$pop_pref"]}, v => 0);	# daily to cumulative
#			}
#		}
		my $death_pref = $jp_rlavr->reduce_cdp_target({item => $deaths, prefectureNameJ => $pref});
		#$death_pref->dump({search_key => "東京都"});
		my $death_max = $death_pref->max_val({start_date => $start_date})/ 100;
		$death_max = 1/999 if($death_max <= 0);
		#
		#	calc_record,, dump見ながら、カラムを合わせてやりました
		#
		$death_pref->calc_record({dlm => ",", result => "$pref#$deaths,,,,$pref#$deaths"."_p", op => ["$pref#$deaths", "/=$death_max"], v => 0});
		#my $death_pref1 = $jp_rlavr->reduce_cdp_target({item => $deaths, prefectureNameJ => "$pref#deaths" . "_p"});
		#dp::dp "death_max: $death_max x 100\n";
		#$death_pref->dump();

		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defjpvac::VACCINE_GRAPH, dsc => "$pref Vaccine(over 65), Positive and Deaths(rlavr 7)", start_date => $start_date, 
			ylabel => "confermed", y2label => "vaccine rate(%) and deaths",
			ymin => 0, y2min => 0,
			additional_plot => $percent_axis,
			graph_items => [
				{cdp => $cdp,  item => {prefecture => $pref, age => "ge65", status => "1-cp"}, static => "", graph_def => $line_thick, axis => "y2"},
				{cdp => $cdp,  item => {prefecture => $pref, age => "ge65", status => "2-cp"}, static => "", graph_def => $line_thick, axis => "y2"},
				{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "1-cp"}, static => "", graph_def => $line_thick_dot, axis => "y2"},
				{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "2-cp"}, static => "", graph_def => $line_thick_dot, axis => "y2"},
				#{cdp => $cdp,  item => {prefecture => $pref, age => "le64", status => "any-cp"}, static => "", graph_def => $box_fill_solid, axis => "y2"},
				{cdp => $death_pref,  item => { prefectureNameJ => "$pref#$deaths"."_p"}, static => "", graph_def => "$line_thin_dot lc rgb 'gray20'", axis => "y2"},
				{cdp => $jp_rlavr,  item => {item => $positive, prefectureNameJ => $pref}, static => "", graph_def => $line_thin_dot},
				#{cdp => $death_pref,  item => { prefectureNameJ => "$pref"}, static => "", graph_def => $line_thick, axis => "y2"},
			],
		}));

#		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
#		{gdp => $defjpvac::VACCINE_GRAPH, dsc => "$pref Vaccine(all age), Positive and Deaths(rlavr 7)", start_date => $start_date, 
#			ylabel => "confermed", y2label => "vaccine rate(%) and deaths",
#			ymin => 0, y2min => 0,
#			additional_plot => $percent_axis,
#			graph_items => [
#				{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "1-cp"}, static => "", graph_def => $box_fill, axis => "y2"},
#				{cdp => $cdp,  item => {prefecture => $pref, age => "all", status => "2-cp"}, static => "", graph_def => $box_fill, axis => "y2"},
#				{cdp => $jp_rlavr,  item => {item => $positive, prefectureNameJ => $pref}, static => "", graph_def => $line_thick},
#				{cdp => $death_pref,  item => { prefectureNameJ => "$pref#$deaths"."_p"}, static => "", graph_def => $line_thick, axis => "y2"},
#				#{cdp => $death_pref,  item => { prefectureNameJ => "$pref"}, static => "", graph_def => $line_thick, axis => "y2"},
#			],
##		}));
	}

	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			html_tilte => "COVID-19 vaccine from CIO",
			src_url => "src_url",
			html_file => "$HTML_PATH/vaccine.html",
			alt_graph => "./japanpref_pop.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}

#
#	OWID VACCINE
#
if($golist{owidvac})
{
	dp::set_dp_id("owidvac");
	my $cdp = csv2graph->new($defowid::OWID_VAC_DEF); 						# Load Apple Mobility Trends
	$cdp->load_csv({download => $DOWNLOAD});
	&completing_zero($cdp);

	@$gp_list = ();
	my $start_date = 0;
	my $percent_axis = "";
	#"England", "Scotland","Northern Ireland","Wales",	#####  No data in Johns Hopkins
	my @target_region = (		# use TARGET REGION
			"Japan", "United States", "Israel", 
			"United Kingdom", "France", "Germany", "Italy", "Spain", "Netherlands", "Sweden", "Russia", 
			"Estonia", "Romania", "Bulgaria", "Hungary", "Slovakia", "Slovenia", 
			"China", "India", "Indonesia", "South Korea", "Singapore", "Taiwan", 
			"Australia", "New Zealand",
			"Brazil", "Mexico", "Colombia", "Peru",
			"South Africa", 
	);
	my @target_area = ("World", "Asia", "Europe", "Africa");

	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);
	foreach my $wcdp ($ccse_cdp, $death_cdp){
		foreach my $country ("Canada", "China", "Australia"){
			$wcdp->calc_items("sum", 
						{"Province/State" => "", "Country/Region" => $country},		
						{"Province/State" => "null", "Country/Region" => "="}	
			);
		}
	}
#	foreach my $wcdp ($ccse_cdp, $death_cdp){
#		foreach my $country ("England", "Scotland","Northern Ireland","Wales"){
#			$wcdp->calc_items("sum", 
#						{"Province/State" => "$country", "Country/Region" => "United Kingdom"},			
#						{"Province/State" => "null", "Country/Region" => "$country"}		
#			);
#			$wcdp->dump({search_key => "$country", items => 200});
#		}
#	}
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country

	my $positive_rlavr = $ccse_country->calc_rlavr();
	my $death_rlavr = $death_country->calc_rlavr();

	my @adp = ();
	my $pct_gap = 10;
	for(my $i = 1; ($i * $pct_gap) < 100; $i++){
		my $pct = $i * $pct_gap; 
		my $dt = (($pct % 20) == 0 ) ? "lc 'blue' dt (3,7)" : "lc 'blue' dt (2,8)";
		#my $dt = "lc 'red' dt (6,4)";
		my $title = "title '$pct%'";
		push(@adp, "$pct axis x1y2 with lines notitle lw 1 $dt");
	}
	$percent_axis = join(",\\\n", @adp);


	my $target_location = join(",", @target_area, @TARGET_REGION); # @target_region);
	#my @select_items = ("total_vaccinations_per_hundred","people_fully_vaccinated_per_hundred");
	my @select_items = ("people_vaccinated_per_hundred","people_fully_vaccinated_per_hundred");
	my $lank_width = int(0.99999 + ($#TARGET_REGION + 1)/ 2);
	$lank_width = 10;
	dp::dp "[lank: $lank_width] " . $#TARGET_REGION . "\n";

	my $target_item = $select_items[1];
	my $graph_items = [];
	#my @compare_country =  ("Israel", "United Kingdom", "United States","Singapore", "Spain", "Ireland","Netherlands", "Italy", "Germany","France","Sweden");
	push(@$graph_items, {cdp => $cdp,  item => {location => "Japan", item_name => $target_item}, static => "", graph_def => "$box_fill_solid lc rgb 'gray'",}); #"$line_thick lc rgb 'red'", });
	my @compare_country =  ("Israel", "United Kingdom", "United States","Singapore", "Spain", "Ireland","Germany");
	foreach my $target_location (@compare_country){
		push(@$graph_items, {cdp => $cdp,  item => {location => $target_location, item_name => $target_item}, static => "", graph_def => $line_thick, });
	}
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defowid::OWID_VAC_GRAPH, dsc => "OWID Vaccine selected region", start_date => $start_date, 
		#sort_start => -200,	#### 2021.11.27
		graph_tag => "World",
		ylabel => "vaccine rate(%)",
		ymin => 0, ymax => 100, y2min => 0, y2max => 100,
		term_y_size => $TERM_Y_SIZE,
		label_sub_from => '#.*', label_sub_to => '',	# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
		additional_plot => $percent_axis,
		graph_items => $graph_items,
	}));

	foreach my $target_item (@select_items){
		for(my $lank = 1; $lank < 20; $lank += $lank_width){
			my $le = $lank + $lank_width - 1;
			my $graph_items = [{cdp => $cdp,  item => {location => $target_location, item_name => $target_item}, static => "", graph_def => $line_thin, },];
			#if($target_item eq "people_vaccinated_per_hundred" && $lank == 1){
			#	push(@$graph_items, {cdp => $cdp,  item => {location => "Japan", item_name => $target_item}, static => "", graph_def => "$line_thick lc rgb 'red'", });
			#}
			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $defowid::OWID_VAC_GRAPH, dsc => "[$target_item](#$lank-$le) OWID Vaccine", start_date => $start_date, 
				#sort_start => -200,	#### 2021.11.27
				graph_tag => "World",
				ylabel => "vaccine rate(%)",
				ymin => 0, ymax => 100, y2min => 0, y2max => 100,
				lank => [$lank, $le],
				label_sub_from => '#.*', label_sub_to => '',	# change label "1:Israel#people_vaccinated_per_hundred" -> "1:Israel"
				additional_plot => $percent_axis,
				graph_items => $graph_items,
#				graph_items => [
#					{cdp => $cdp,  item => {location => $target_location, item_name => $target_item}, static => "", graph_def => $line_thin, },
#				],
			}));
		}

	}

	foreach my $region (@target_area) { # , @target_region)
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defowid::OWID_VAC_GRAPH, dsc => "[$region] OWID Vaccine", start_date => $start_date, 
			ylabel => "vaccine rate(%)",
			ymin => 0, ymax => 100, y2min => 0,y2max => 100,
			additional_plot => $percent_axis,
			graph_items => [
				{cdp => $cdp,  item => {location => $region,}, static => "", graph_def => $line_thick, },
			],
		}));
	}


	$start_date = "2021-01-01";

	foreach my $region (@target_region){
		my $ccse_reg = $region;
		$ccse_reg = "Taiwan*" if($region eq "Taiwan");
		$ccse_reg = "Korea-South" if($region eq "South Korea");
		$ccse_reg = "US" if($region eq "United States");

		my $cdp_p = $ccse_country->reduce_cdp_target({"Province/State" => "NULL", "Country/Region" => $ccse_reg});	# Select Country
		my $cdp_d  = $death_country->reduce_cdp_target({"Province/State" => "NULL", "Country/Region" => $ccse_reg});	# Select Country
		$positive_rlavr = $cdp_p->calc_rlavr();
		$death_rlavr = $cdp_d->calc_rlavr();
		my $death_max = $death_rlavr->max_val({start_date => $start_date}) / 100;
		$death_rlavr->calc_record({dlm => "#", result => "##$ccse_reg--death_p#", op => ["$ccse_reg--death", "/=$death_max"]});			# daily to cumulative

		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defowid::OWID_VAC_GRAPH, dsc => "[$region] OWID Vaccine, Positive and Deaths(rlavr 7)", start_date => $start_date, 
			ylabel => "confermed", y2label => "vaccine rate(%) and deaths/max(%)",
			ymin => 0, y2min => 0,y2max => 100,
			term_y_size => $TERM_Y_SIZE,
			additional_plot => $percent_axis,
			graph_items => [
				#{cdp => $cdp,  item => {location => $region, item_name => "total_vaccinations_per_hundred"}, static => "", graph_def => $box_fill, axis => "y2"},
				{cdp => $cdp,  item => {location => $region, item_name => "people_vaccinated_per_hundred"}, static => "", graph_def => $box_fill, axis => "y2"},
				{cdp => $cdp,  item => {location => $region, item_name => "people_fully_vaccinated_per_hundred"}, static => "", graph_def => $box_fill, axis => "y2"},
				{cdp => $positive_rlavr,  item => {"Country/Region" => "$ccse_reg"}, static => "", graph_def => $line_thick},
				{cdp => $death_rlavr,  item => {"Country/Region" => "$ccse_reg--death_p"}, static => "", graph_def => $line_thick, axis => "y2"},
			],
		}));
	}

	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			row => 2,
			html_tilte => "COVID-19 vaccine from OWID",
			src_url => "src_url",
			html_file => "$HTML_PATH/owidvac.html",
			#alt_graph => "./japanpref_pop.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
	#exit;
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
if($golist{docomo}){
	dp::set_dp_id("docomo");
	my $docomo_gp_list = [];
	dp::dp "DOCOMO\n";
	my @docomo_base = ("感染拡大前比", "緊急事態宣言前比"); #, "前年同月比", "前日比"); 
	my $start_date = 0;
	my $docomo_cdp = csv2graph->new($defdocomo::DOCOMO_DEF); 						# Load Johns Hopkings University CCSE
	$docomo_cdp->load_csv($defdocomo::DOCOMO_DEF);

	my @tokyo = (qw (東京都));
	my @kanto = (qw (東京都 神奈川県 千葉県 埼玉県 茨木県 栃木県 群馬県));
	my @kansai = (qw (大阪府 京都府 兵庫県 奈良県 和歌山県 滋賀県));
	my @tokai = (qw (愛知県 岐阜県 三重県 静岡県));
	my @touhoku = (qw (青森県 秋田県 岩手県 宮城県 山形県 福島県));
	my @koushin = (qw (山梨県 長野県));
	my @hokuriku = (qw (新潟県 富山県 石川県 福井県));
	my @chugoku = (qw (鳥取県 島根県 岡山県 広島県 山口県));
	my @shikoku = (qw (香川県 愛媛県 徳島県 高知県));
	my @kyusyu = (qw (福岡県 佐賀県 長崎県 熊本県 大分県 宮崎県 鹿児島県 沖縄県));

	my	@SUMMARY = (
		{name => "全国", target => []},
		{name => "関東", target => [@kanto]},
		{name => "関西", target => [@kansai]},
		{name => "東海", target => [@tokai]},
		{name => "東京", target => ["東京都"]},
		{name => "大阪", target => ["大阪府"]},
	#	{name => "名古屋", target => ["愛知県"]},
	);


	foreach my $region ("~東京", "~大阪"){
		foreach my $base (@docomo_base){
			foreach my $static ("", "rlavr"){
				push(@$docomo_gp_list, , csv2graph->csv2graph_list_gpmix(
					{gdp => $defdocomo::DOCOMO_GRAPH, dsc => "Tokyo docmo $base $static $region", start_date => $start_date, 
						ymin => "", ymax => "", ylabel => "number", lank => [1,20], label_subs => '#.*$',
						additional_plot => $additional_plot_item{docomo}, 
						graph_items => [
						{cdp => $docomo_cdp, item => {area => $region, base => $base}, static => "$static", graph_def => $line_thin,},
						],
					},
				));
			}
		}
	}
	csv2graph->gen_html_by_gp_list($docomo_gp_list, {						# Generate HTML file with graphs
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/docomo.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => "data_source",
		}
	);
}


#
#
#
sub	ccse_positive_death
{
	my($conf_cdp, $death_cdp, $region, $start_date) = @_;

	my $p = {start_date => $start_date};
	my $conf_region = $conf_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	my $y1max = $conf_region->max_rlavr($p);
	my $y2max = int($y1max * $y2y1rate / 100 + 0.9999999); 
	my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 

	my $death_region = $death_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	# $death_region->rolling_average();
	my $death_max = $death_region->max_rlavr($p);

	my $drate = sprintf("%.2f%%", 100 * $death_max / $y1max);
	#dp::dp "y0max:$y0max y1max:$y1max, ymax:$ymax, y2max:$y2max death_max:$death_max\n";


	my @list = ();
	push(@list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defccse::CCSE_GRAPH, dsc => "[$region] new cases and deaths [$drate]", start_date => $start_date, 
			ymax => $ymax, y2max => $y2max, y2min => 0,
			ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
			#additional_plot => $additional_plot_item{ern}, 
			graph_items => [
			{cdp => $conf_cdp,  item => {$cntry => "$region",}, static => "rlavr", graph_def => $line_thick},
			{cdp => $death_cdp, item => {$cntry => "$region",}, static => "rlavr", axis => "y2", graph_def => $box_fill},
			{cdp => $conf_cdp,  item => {$cntry => "$region",}, static => "", graph_def => $line_thin_dot,},
			{cdp => $death_cdp, item => {$cntry => "$region",}, static => "", axis => "y2", graph_def => $line_thin_dot},
			],
		},
	));
	return (@list);
}

sub	usa_positive_death
{
	my($conf_cdp, $death_cdp, $region, $start_date) = @_;

	my $p = {start_date => $start_date};
	my $conf_region = $conf_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	my $y1max = $conf_region->max_rlavr($p);
	my $y2max = int($y1max * $y2y1rate / 100 + 0.9999999); 
	my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 

	my $death_region = $death_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	# $death_region->rolling_average();
	my $death_max = $death_region->max_rlavr($p);

	my $drate = sprintf("%.2f%%", 100 * $death_max / $y1max);
	#dp::dp "y0max:$y0max y1max:$y1max, ymax:$ymax, y2max:$y2max death_max:$death_max\n";


	my @list = ();
	push(@list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defccse::CCSE_GRAPH, dsc => "[$region] new cases and deaths [$drate]", start_date => $start_date, 
			ymax => $ymax, y2max => $y2max, y2min => 0,
			ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
			#additional_plot => $additional_plot_item{ern}, 
			graph_items => [
			{cdp => $conf_cdp,  item => {$cntry => "$region",}, static => "rlavr", graph_def => $line_thick},
			{cdp => $death_cdp, item => {$cntry => "$region",}, static => "rlavr", axis => "y2", graph_def => $box_fill},
			{cdp => $conf_cdp,  item => {$cntry => "$region",}, static => "", graph_def => $line_thin_dot,},
			{cdp => $death_cdp, item => {$cntry => "$region",}, static => "", axis => "y2", graph_def => $line_thin_dot},
			],
		},
	));
	return (@list);
}
sub	search_cdp_key
{
	my($cdp, $key, $post) = @_;

	#$cdp->dump();
	#dp::dp "key:$key post:$post\n"; 

	my $csvp = $cdp->{csv_data};
	my @keys = ($key);
	if($key =~ /,/){
		@keys = split(/,/, $key);
	}
	foreach my $k (@keys){
		return ($k . $post) if(defined $csvp->{"$k" . $post});
		if($k =~ /\~/){
			$k =~ s/\~//;
			foreach my $csvk (keys %$csvp){
				if($csvk =~ /$k/){
					dp::dp "[$csvk]\n";
					$csvk =~ s/"//g;
					return ($csvk);
				}
			}
		}
	}	
	return ""; 
}

sub	ccse_positive_death_ern
{
	my($conf_cdp, $death_cdp, $region, $start_date, $pop, $kind, $end_date) = @_;

	$end_date = $end_date // "";
	my $conf_region = $conf_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	my $death_region = $death_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	my $p = "";
	my $pync = ($end_date) ? 10 : $POP_YMAX_NC_WW;
	my $pynd = ($end_date) ? $POP_YMAX_ND_JP : $POP_YMAX_ND_WW;
	dp::dp "POP: $pync $pynd\n";
	if($pop){
		$p = {pop_ymax_nc => $pync, pop_ymax_nd => $pynd, start_date => $start_date};		# 2 -> 1 2021.07.29
	}
	my $gdp = $defccse::CCSE_GRAPH;
	
	return &positive_death_ern($conf_region, $death_region, $region, $start_date, "--conf", "--death", $p, $kind, $gdp, $end_date);
}

sub	japan_positive_death_ern
{ 
	my($jp_pcdp, $jp_dcdp, $pref, $start_date, $pop, $kind) = @_;

	#$jp_pcdp->dump();
	#$jp_dcdp->dump();
	#my $jp_pref = $jp_cdp->reduce_cdp_target({item => $positive, prefectureNameJ => $pref});
	#my $death_pref = $jp_cdp->reduce_cdp_target({item => $deaths, prefectureNameJ => $pref});
	#dp::dp $jp_cdp->dump();
	my $jp_pref = $jp_pcdp->reduce_cdp_target({pref => "$pref-positive"});
	my $death_pref = $jp_dcdp->reduce_cdp_target({pref => "$pref-deaths"});
	#$jp_pref->dump();
	#$death_pref->dump();
	my $p = "";

	if($pop){
		my $pop_ymax_nc = ((!$start_date =~ /\D/) && $start_date > $RECENT) ? $POP_YMAX_NC_JP : $POP_YMAX_NC_JP_SHORT;  
		dp::dp "POP_YMAX [$start_date:$RECENT] $pop_ymax_nc\n";
		$p = {pop_ymax_nc => $pop_ymax_nc, pop_ymax_nd => $POP_YMAX_ND_JP, start_date => $start_date};
	}
	my $gdp = $defnhk::DEF_GRAPH;
	
	return &positive_death_ern($jp_pref, $death_pref, $pref, $start_date, "-positive", "-deaths", $p, $kind, $gdp);
}

sub	positive_death_ern
{
	my($conf_region, $death_region, $region, $start_date, $conf_post_fix, $death_post_fix, $p, $kind, $gdp, $end_date) = @_;

	#$conf_region->dump();
	#$death_region->dump();
	$kind = $kind // "no-kind";
	$end_date = $end_date // "";
	#dp::dp "End date: [$end_date]\n";
	$p = {start_date => $start_date} if(!($p // ""));
	my $pop_ymax_nc = $p->{pop_ymax_nc} // "";
	my $pop_ymax_nd = $p->{pop_ymax_nd} // "";
	# dp::dp "[$pop_ymax_nc,$pop_ymax_nd]\n";

	my $nc_max = $conf_region->max_rlavr($p);
	dp::dp ">>>> $nc_max\n";
	$nc_max = 1 if($nc_max <= 0);
	my $nc_max_week = $conf_region->max_rlavr($p);

	my $rlavr = $conf_region->calc_rlavr();
	my $ern = $conf_region->calc_ern();
	my $csvp = $ern->{csv_data};
	my $key = &search_cdp_key($conf_region, $region, $conf_post_fix);
	if(! $key || !($csvp->{$key}//"")){
		dp::ABORT "$key undefined \n";
		return "";
	}
	dp::dp "KEY[$key]\n";

	my $pop_key = $key; # $region;
	$pop_key =~ s/$conf_post_fix//;
	my $population = $POP{$pop_key} // 100000;

	if(! defined $POP{$pop_key}){
		dp::ABORT "POP: $pop_key, not defined\n";
		$population = 100000;
	}
	my $pop_100k = $population / 100000;

	my $ymax = csvlib::calc_max2($nc_max);			# try to set reasonable max 
	my $y2max = int($nc_max * $y2y1rate / 100 + 0.9999999); 
	if($pop_ymax_nc){
		dp::ABORT "POP: pop_ymax_nd, not defined\n" if(!$pop_ymax_nd);

		#dp::dp ">>>> ", join(", ", $ymax, $pop_ymax_nc, $pop_100k, $pop_ymax_nc * $pop_100k) . "\n";
		$ymax = csvlib::calc_max2($pop_100k * $pop_ymax_nc);
		$y2max = $pop_100k * $pop_ymax_nd;
	}

	my $death_rlavr = $death_region->calc_rlavr();
	my $nd_max = $death_region->max_rlavr($p);

	#my $drate = sprintf("%.2f%%", 100 * $death_max / $nc_max);
	#my $drate = 100 * $death_max / $nc_max;

	#dp::dp "y0max:$y0max nc_max:$nc_max, ymax:$ymax, y2max:$y2max death_max:$nd_max\n";

	#$rlavr->dump();

	#
	#	Adjust ERN
	#
	my $csv_region = $csvp->{$key};						# Adjust ERN value for fitting y2max
	my $size = scalar(@$csv_region);
	for(my $i = 0; $i < $size; $i++){
		my $v = $csv_region->[$i];
		$csv_region->[$i] = sprintf("%.3f", $v * $y2max / 3);
		if($key =~ "東京都"){
			printf("$key %.2f -> %.2f %.2f\n", $v, $csv_region->[$i], $y2max / 3);
		}
	}
	$ern->rename_key($key, "$region-ern");

	#
	#	Lines of ERN
	#
	my @adp = ();
	for(my $i = 0; $i < 3; $i += 0.2){
		next if($i == 0);

		my $ern_line = sprintf("%.3f", $i * $y2max / 3);
		my $dt = "lc 'royalblue' dt (3,7)";
		my $f = int($i * 100) % 100;
		$f = sprintf("%.2f", $i);
		my $title = "notitle";
		#dp::dp sprintf("ADP: %.5f: %.5f %d", $i,  int($i), $f)  . "\n";
		if($f == int($f)){
			##dp::dp "--> $i\n";
			#$dt = ($i == 1) ? "lc 'red' dt (5,5)" : "lc 'red'";
			$dt = ($i == 1) ? "lc 'red' dt (6,4)" : "lc 'red' dt (3,7)";
			$title = "title 'ern=$i.0'";
		}
		push(@adp, "$ern_line axis x1y2 with lines $title lw 1 $dt");
	}
	my $add_plot = join(",\\\n", @adp);

	##
	## POP
	##
	#dp::dp "[$pop_key]: $pop_100k\n";
	my $pop_max = $ymax / $pop_100k;
	my $nc_last = $rlavr->last_data($key);
	if($nc_last <= 0){
		$nc_last = 0.9999; # 1 / ($population * 2));
	}
	my $week_pos = -7;
	my $nc_last_week = $rlavr->last_data($key, {end_date => ($week_pos)});
	my $pop_last  = $nc_last / $pop_100k;

	$add_plot .= ",\\\n" . &gen_pop_scale({pop_100k => $pop_100k, pop_max => $pop_max, 
					lc => "navy", title_tag => 'Positive %.1f/100K', axis => "x1y1"});

	#
	#	POP Death
	#
	#my $nd_max = $death_region->max_rlavr($p);
#	my @gcl = ("#0070f0", "#e36c09", "forest-green", "dark-violet", 			# https://mz-kb.com/blog/2018/10/31/gnuplot-graph-color/
#				"dark-pink", "#00d0f0", "#60d008", "brown",  "gray50", 
#				);

	my @death_pop = ();
	my ($d100k, $dn_unit, $unit_no) = ();
	my @color = ();
	my @d100k_list = (0.5, 0.2, 0.1, 0.05, 0.02, 0.01);
	my $rg = $region;
	$rg =~ s/,*$//;
	my $d_max = ($nd_max < $y2max) ? $nd_max : $y2max ;		# $nd_max;
	#my $d_max = $nd_max;									# moving scale seems wrong

	#dp::dp "$d_max  $nd_max : $y2max\n";
	for(my $i = 0; $i <= $#d100k_list; $i++){
		#$dn_unit = csvlib::calc_max2($nd_max) / 2;			# try to set reasonable max 
		$d100k = $d100k_list[$i];
		$dn_unit = $pop_100k * $d100k;	
		$unit_no = int(0.99999999 + $d_max / $dn_unit);
		@color = ($bcl[$i*2], $bcl[$i*2+1]);
		#dp::dp "$rg: $d100k : $unit_no $d_max / $dn_unit => " . sprintf("%.2f", $d_max / $dn_unit) . "\n";
		if(($d_max / $dn_unit) >= 2.5){
			#dp::dp "LAST\n";
			last;
		}
	}
	if($dn_unit < 1){
		$dn_unit = 1 ;
		$unit_no = int(0.99999999 + $d_max / $dn_unit);
	}

	#dp::dp "d_max: $d_max, pop_100k: $pop_100k, dn_unit: $dn_unit, unit_no: $unit_no\n";
	my $dkey = &search_cdp_key($death_region, $region, $death_post_fix);
	my $nd_last 	 = $death_rlavr->last_data($dkey);
	my $nd_last_week = $death_rlavr->last_data($dkey, {end_date => ($week_pos)});
	#my $nd_last_week = $nd_last;
	#dp::dp "===== nd_last_week: $nd_last_week, $nd_last\n";
	#dp::dp "region:$region dkey[$dkey]\n";
	for(my $i = 0; $i < $unit_no; $i++){
		$death_pop[$i] = $death_rlavr->dup();
		my $du = $dn_unit * $i;

		#dp::dp "$i: $du  $dn_unit\n";
		$csvp = $death_pop[$i]->{csv_data}->{$dkey};
		#dp::dp "[$csvp]\n";
		#$death_pop[$i]->dump();
		my $dmax = $death_pop[$i]->{dates};
		#dp::dp "[$i] $du0 : $d_max:";
		for(my $dt = 0; $dt <= $dmax; $dt++){
			my $v = $csvp->[$dt];
			if($v < $du){
				$v = 0; #"NaN";
			}
			elsif($v > ($du + $dn_unit)) {
				$v = $du + $dn_unit;
			}
			$csvp->[$dt] = $v;
			#$csvp->[$dt] = ($v < $du) ? $v: $du;
			#print "[$v:" . $csvp->[$dt] . "]";
		}	
		#print "\n";
	}
	
	my $graph_items = [];
	my @gtype = (
		#'boxes fill solid border lc rgb "' . $color[1] . '" lc rgb "' . $color[0] . '"',
		#'boxes fill solid border lc rgb "' . $color[0] . '" lc rgb "' . $color[1] . '"',
		'boxes fill solid 0.25 border lc rgb "gray60" lc rgb "' . $color[0] . '"',
		'boxes fill solid 0.25 border lc rgb "gray60" lc rgb "' . $color[1] . '"',
	);

	for(my $i = $unit_no - 1; $i >= 0; $i--){
		my $gn = $i % ($#gtype + 1);
		my $graph_type = $gtype[$gn];
		$graph_type .= " notitle" if($i > 0);
		#dp::dp "gn: $gn, type: " . ($graph_type // "--") . " static\n";
		#if($i => $unit_no){
			$death_pop[$i]->rename_key($dkey, sprintf("$dkey-%.2f/100K", $d100k));
		#}
		push(@$graph_items, 
			{cdp => $death_pop[$i], item => {}, static => "", axis => "y2", graph_def => $graph_type}
		);
	}

	push(@$graph_items, 
			{cdp => $conf_region, item => {}, static => "rlavr", graph_def => ("$line_thick lc rgb \"" . $gcl[3] . "\"")},
			{cdp => $ern,  item => {}, static => "", axis => "y2", graph_def => ("$line_thick_dot lc rgb \"" . $gcl[0] . "\"")},
			{cdp => $conf_region,  item => {}, static => "", graph_def => ("$line_thin_dot2 lc rgb \"" . $gcl[3] . "\""),},
			{cdp => $death_region, item => {}, static => "", axis => "y2", graph_def => ("$line_thin_dot2 lc rgb \"" . $color[0] . "\"")},
	);

	my @list = ();
	my $dmax_pop = $d_max / $pop_100k;
	my $dlst_pop = $nd_last / $pop_100k;
	dp::dp ">>> $d_max/$nc_max\n";
	my $drate_max = 100 * $d_max / $nc_max;
	my $drate_last = 100 * $nd_last / $nc_last;
	my $pop_dsc = sprintf("pp[%.1f,%.1f] dp[%.2f,%.2f](max,lst) pop:%d",
		$pop_max, $pop_last, $d_max / $pop_100k, $nd_last / $pop_100k, $pop_100k);
	if($pop_ymax_nc){
		$pop_dsc = sprintf("pop[%d, nc:%.1f, nd:%.1f]", $pop_100k, $pop_ymax_nc, $pop_ymax_nd);
	}
	#dp::dp "===== " .join(",", $region, $nc_last, $nc_last_week,  $nc_last / $nc_last_week) . "\n";
	#dp::dp "===== " .join(",", $region, $nd_last, $nd_last_week,  $nd_last / $nd_last_week) . "\n";
	my $nc_week_diff = ($nc_last_week > 0) ? ($nc_last / $nc_last_week) : 0; 
	my $nd_week_diff = ($nd_last_week > 0) ? ($nd_last / $nd_last_week) : 0;

	my $y2label = ($pop_ymax_nc) ? "deaths" : "deaths (max=$y2y1rate% of rlavr confermed)";
	dp::dp "src_info: " . $conf_region->{src_info} . "\n";
	push(@list, $conf_region->csv2graph_list_gpmix(
		{gdp => $gdp, dsc => "[$rg] $kind", sub_dsc => sprintf("$pop_dsc dr:%.2f%%", $drate_max), start_date => $start_date, end_date => $end_date,
			ymax => $ymax, y2max => $y2max, y2min => 0,
			ylabel => "confermed", y2label => $y2label ,
			term_y_size => $TERM_Y_SIZE,
			additional_plot => $add_plot,
			graph_items => [@$graph_items],
			no_label_no => 1,
		},
	));

	#
	#	Data, diff from week
	#
	my $reg = "$region#$start_date";
	for(my $w = 0; $w < $WEEK_BEFORE; $w++){
		my $wd = -$w * 7;
		my $p = ($w == 0) ? {end_date => ""} : {end_date => $wd};
		my $lp = {end_date => ($wd - 7)};
		my $_nc_last 	  = $rlavr->last_data($key, $p);
		my $_nc_last_week = $rlavr->last_data($key, $lp);
		my $_nd_last 	  = $death_rlavr->last_data($dkey, $p);
		my $_nd_last_week = $death_rlavr->last_data($dkey, $lp);
		my $_pop_last  = $_nc_last / $pop_100k;
		my $_dlst_pop = $_nd_last / $pop_100k;
		my $_drate_last = 100 * $_nd_last / &zd($_nc_last);

#		if($_nc_last_week <= 0){
#			$_nc_last_week = (($_nc_last == 0) ? 1 : $_nc_last) / 999;
#		}
#		if($_nd_last_week <= 0){
#			$_nd_last = 1 if($_nd_last == 0);
#			$_nd_last_week = $_nd_last / 999 ;
#		}
		my $_nc_week_diff = ($_nc_last_week > 0) ? ($_nc_last / $_nc_last_week) : 0;
		my $_nd_week_diff = ($_nd_last_week > 0) ? ($_nd_last / $_nd_last_week) : 0;

		$REG_INFO_LIST[$w] = {} if(! defined $REG_INFO_LIST[$w]);
		#dp::dp "### $w $start_date [$reg] $_nc_last, $_nd_last\n";
		$REG_INFO_LIST[$w]->{$reg} = {	
				nc_max => sprintf("%.3f", $nc_max), nd_max => sprintf("%.3f", $d_max), 
				nc_week_diff => sprintf("%.3f", $_nc_week_diff), nd_week_diff => sprintf("%.3f", $_nd_week_diff), 
				nc_last => sprintf("%.3f", $_nc_last), nd_last => sprintf("%.3f", $_nd_last), 
				nc_pop_max => sprintf("%.3f", $pop_max), nc_pop_last => sprintf("%.3f", $_pop_last), 
				nd_pop_max => sprintf("%.3f", $dmax_pop), nd_pop_last => sprintf("%.3f", $_dlst_pop),
				drate_max => sprintf("%.3f", $drate_max) , drate_last => sprintf("%.3f", $_drate_last),
				nc_last_1 => sprintf("%.3f", $_nc_last_week), nd_last_1 => sprintf("%.3f", $_nd_last_week),
				nc_pop_1 => sprintf("%.3f", $_nc_last_week / $pop_100k), nd_pop_1 => sprintf("%.3f", $_nd_last_week / $pop_100k),
				pop_100k => sprintf("%.1f", $pop_100k), 
		};
	
	}
	return (@list);
}


#
#
#
sub	calc_dlt
{
	my($pop_max) = @_;
	#my @dlt = (10, 5, 2.5, 2, 1); 
	my @dlt = (0.2, 0.25, 0.5, 1, 2, 2.5, 5, 10); 

	for(my $dlt_dig = 0; $dlt_dig < 5; $dlt_dig++){
		my $dig = 10**($dlt_dig);
		foreach my $d (@dlt){
			my $dd = $d * $dig;
			my  $dlt = $pop_max / $dd;
			#dp::dp "digit: $dlt $dd, $dig * $dlt_dig [$pop_max]\n";
			return $dd if($dlt < 5.9) ;#5.9);
		}
	}
	dp::ABORT "$pop_max\n";
	return "";
}

#
#
#
sub	gen_pop_scale
{
	my($p) = @_;
	my $pop_100k = $p->{pop_100k} // dp::ABORT "pop_100k";
	my $pop_max  = $p->{pop_max} // dp::ABORT "pop_max";
	my $lc = $p->{lc} // "navy";
	my $title_tag = $p->{title_tag}// "csv2graph";
	my $axis = $p->{axis} // "x1y1";
	#my $pop_dlt = $p->{init_dlt} // 2.5;

	my $line_def = "lc '$lc' dt (5,5)";

	my $pop_dlt = &calc_dlt($pop_max);
	#dp::dp "dlt: $pop_max -> $pop_dlt\n";

	my @adp = ();
	my $ln = 0;
	for(my $i = $pop_dlt; $i < $pop_max; $i +=  $pop_dlt, $ln++){
		my $pop = $i * $pop_100k;
		my $lw = 1;
		my $dt = $line_def;
		if(($ln % 2) == 1){
			$dt =~ s/dt.*$//;
			if(($pop_max / $pop_dlt) < 5 ){
				$lw = 1.5 if(($ln % 2) == 1);
			}
			else {
				$lw = 1.5 if(($ln % 4 ) == 3);
			}
		}
		if(($i % 10) == 0){
			$dt =~ s/dt.*$//;
		}
		#my $title = sprintf("title 'Positive %.1f/100K'", $i);
		my $title = sprintf("title '$title_tag'", $i);
		push(@adp, "$pop axis $axis with lines $title lw $lw $dt");
	}
	my $add_plot = join(",\\\n", @adp);
	return $add_plot;
}

sub	zd
{
	my($v) = @_;

	$v = 1 / 999 if($v == 0);
	return $v;
}


#
#
#
sub	japan_positive_death
{ 
	my($jp_cdp, $pref, $start_date) = @_;


	my $p = {start_date => $start_date};
	my $jp_pref = $jp_cdp->reduce_cdp_target({item => $positive, prefectureNameJ => $pref});
	my $y1max = $jp_pref->max_rlavr($p);
	my $y2max = int($y1max * $y2y1rate / 100 + 0.9999999); 

	my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 
	my $death_pref = $jp_cdp->reduce_cdp_target({item => $deaths, prefectureNameJ => $pref});
	my $death_max = $death_pref->max_rlavr($p);

	my $drate = sprintf("%.2f%%", 100 * $death_max / $y1max);
	dp::dp "y1max:$y1max, ymax:$ymax, y2max:$y2max death_max:$death_max\n";

	my @list = ();
	push(@list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defjapan::JAPAN_GRAPH, dsc => "Japan [$pref] new cases and deaths", sub_dsc => "[$drate]", start_date => $start_date, 
			ymax => $ymax, y2max => $y2max, ymin => 0, y2min => 0,
			ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
			#additional_plot => $additional_plot_item{ern}, 
			graph_items => [
			{cdp => $jp_cdp, item => {item => $positive, prefectureNameJ => $pref}, static => "rlavr", graph_def => $line_thick},
			{cdp => $jp_cdp, item => {item => $deaths,   prefectureNameJ => $pref}, static => "rlavr", axis => "y2", graph_def => $box_fill},
			{cdp => $jp_cdp, item => {item => $positive, prefectureNameJ => $pref}, static => "", graph_def => $line_thin_dot,},
			{cdp => $jp_cdp, item => {item => $deaths,   prefectureNameJ => $pref}, static => "", axis => "y2", graph_def => $line_thin_dot},
			],
		},
	));
	return (@list);
}

#
#
#
sub	ccse_positive_ern
{
	my($conf_cdp, $region, $start_date) = @_;

	my $conf_region = $conf_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	my $p = {start_date => $start_date};
	my $y1max = $conf_region->max_rlavr($p);
	my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 

	my @list = ();
	push(@list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defccse::CCSE_GRAPH, dsc => "[$region] new cases and ern", start_date => $start_date, 
			ymax => $ymax, y2max => 3, ymin => 0, y2min => 0,
			additional_plot => $additional_plot_item{ern}, 
			graph_items => [
			{cdp => $conf_region, item => {}, static => "rlavr"},
			{cdp => $conf_region, item => {}, static => "ern",  axis => "y2"},
			{cdp => $conf_region, item => {}, static => "",     graph_def => $line_thin_dot},
			],
		},
	));
	return (@list);
}
#
#
#
sub	japan_positive_ern
{
	my($jp_cdp, $pref, $start_date) = @_;

	my $jp_pref = $jp_cdp->reduce_cdp_target({item => $positive, prefectureNameJ => $pref});
	#$jp_pref->dump({items => 100});
	my $p = {start_date => $start_date};
	my $y1max = $jp_pref->max_rlavr($p);
	#$jp_pref->dump({items => 100});
	my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 

	my @list = ();
	push(@list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defjapan::JAPAN_GRAPH, dsc => "[$pref] new cases and ern", start_date => $start_date, 
			ymax => $ymax, y2max => 3, ymin => 0, y2min => 0,
			additional_plot => $additional_plot_item{ern}, 
			graph_items => [
			{cdp => $jp_pref, item => {}, static => "rlavr"},
			{cdp => $jp_pref, item => {}, static => "ern",  axis => "y2"},
			{cdp => $jp_pref, item => {}, static => "",     graph_def => $line_thin_dot},
			#{cdp => $jp_pref, item => {item => $positive, prefectureNameJ => $pref}, static => "",     graph_def => $line_thin_dot},
			],
		},
	));
	return (@list);
}

#
# Load Apple Mobility Trends
#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
my $amt_country = {};		# for marge wtih ccse-ERN
my $amt_pref = {};
my $EU = "United Kingdom,France,Germany,Italy,Belgium,Greece,Spain,Sweden";
if($golist{amt}){
	dp::set_dp_id("amt");
	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	my $amt_cdp = csv2graph->new($AMT_DEF); 										# Init AMD_DEF
	$amt_cdp->load_csv($AMT_DEF);									# Load to memory
	#$amt_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	my $amt_country = $amt_cdp->reduce_cdp_target({geo_type => $REG});
	$amt_country->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	my $amt_pref = $amt_cdp->reduce_cdp_target({geo_type => $SUBR});
	$amt_pref->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	#$amt_pref->dump();
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
		{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends World Wilde avr", start_date => 0, 
			term_y_size => 400,
			graph_items => [
			{cdp => $amt_country, item => { transportation_type => "avr"}, static => "rlavr", graph_def => $line_thick},
			],
		},
		{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends World Wilde driving", start_date => 0, 
			term_y_size => 400,
			graph_items => [
			{cdp => $amt_country, item => { transportation_type => "driving"}, static => "rlavr", graph_def => $line_thick},
			],
		},
		{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends World Wilde walking", start_date => 0, 
			term_y_size => 400,
			graph_items => [
			{cdp => $amt_country, item => { transportation_type => "walking"}, static => "rlavr", graph_def => $line_thick},
			],
		},
		{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends World Wilde transit", start_date => 0, 
			term_y_size => 400,
			graph_items => [
			{cdp => $amt_country, item => { transportation_type => "transit"}, static => "rlavr", graph_def => $line_thick},
			],
		},

		{gdp => $AMT_GRAPH, dsc => "Japan Apple Mobility Trends Simple", start_date => 0, 
			graph_items => [
			{cdp => $amt_country, static => "rlavr", target_col => {region => "Japan", transportation_type => "avr"} , graph_def => $line_thick},
			{cdp => $amt_country, static => "rlavr", target_col => {region => "Japan", transportation_type => "!avr"} , graph_def => $line_thin},
			],
		},
		{gdp => $AMT_GRAPH, dsc => "Japan Apple Mobility Trends Simple", start_date => -90, 
			graph_items => [
			{cdp => $amt_country, static => "rlavr", target_col => {region => "Japan", transportation_type => "avr"} , graph_def => $line_thick},
			{cdp => $amt_country, static => "rlavr", target_col => {region => "Japan", transportation_type => "!avr"} , graph_def => $line_thin},
			],
		},

		{gdp => $AMT_GRAPH, dsc => "Japan Apple Mobility Trends", start_date => -90, 
			graph_items => [
			{cdp => $amt_country, static => "rlavr", target_col => {region => "Japan", transportation_type => "avr"} , graph_def => $line_thick},
			{cdp => $amt_country, static => "rlavr", target_col => {region => "Japan", transportation_type => "!avr"} , graph_def => $line_thin},
			{cdp => $amt_country, static => "", target_col => {region => "Japan", transportation_type => "avr"} , graph_def => $line_thin},
			{cdp => $amt_country, static => "", target_col => {region => "Japan", transportation_type => "!avr"} , graph_def => $line_thin_dot},
			],
		},

		{gdp => $AMT_GRAPH, dsc => "EU Apple Mobility Trends", start_date => 0, 
			graph_items => [
			{cdp => $amt_country, static => "", target_col => {region => $EU, transportation_type => "avr"}, static => "rlavr"},
			],
		},
#		{gdp => $AMT_GRAPH, dsc => "Japan Apple Mobility Trends Prefs ", start_date => 0, 
#			graph_items => [
#			{cdp => $amt_pref, static => "", target_col => {country => "Japan", transportation_type => "avr"}, static => "rlavr"},
#			],
#		},
	));
}

#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
if($golist{"amt-jp"}) {

	dp::set_dp_id("amt-jp");
	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	#
	#	Load AMT
	#
	my $amt_cdp = csv2graph->new($defamt::AMT_DEF); 										# Init AMD_DEF
	$amt_cdp->load_csv($AMT_DEF);									# Load to memory
	#$amt_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	my $amt_pref = $amt_cdp->reduce_cdp_target({geo_type => $SUBR});
	$amt_pref->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	#$amt_pref->dump({ok => 1, lines => 5, search_key => "Japan"});			# Dump for debug

	foreach my $pref (@TARGET_PREF){			# Generate Graph Parameters
		foreach my $start (0, $RECENT, -93){
			my $dt = "";
			$dt = "2m" if($start == $RECENT);
			$dt = "3m" if($start == -93);
			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
				{gdp => $AMT_GRAPH, dsc => "[$pref] Japan focus pref", start_date => $start, y2max => 3,
					graph_items => [
					#{cdp => $amt_pref, static => "",      target_col => {country => "Japan", transportation_type => $AVR, region => "~$pref"},},
					#{cdp => $amt_pref, static => "rlavr", target_col => {country => "Japan", transportation_type => $AVR, region => "~$pref"},},
					{cdp => $amt_pref, static => "",      target_col => {country => "Japan", region => "~$pref"},},
					{cdp => $amt_pref, static => "rlavr", target_col => {country => "Japan", region => "~$pref"},},
					],
				},
			));
		}
	}
}

#
#	Generate Marged Graph of Apple Mobility Trends and CCSE-ERN
#
if($golist{"amt-ccse"})
{
	dp::set_dp_id("amt-ccse");
	#
	#	Apple Mobility Trends
	#
	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	my $amt_cdp = csv2graph->new($AMT_DEF); 										# Init AMD_DEF
	$amt_cdp->load_csv($AMT_DEF);									# Load to memory
	#$amt_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	my $amt_country = $amt_cdp->reduce_cdp_target({geo_type => $REG});
	$amt_country->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	my $amt_pref = $amt_cdp->reduce_cdp_target({geo_type => $SUBR});
	$amt_pref->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);

	#
	#	CCSE
	#
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 							# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	#$ccse_cdp->dump({ok => 1, lines => 1, items => 10, search_key => "Canada"}); # if($DEBUG);
	$ccse_cdp->calc_items("sum", 
				{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
				{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
	);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	#$ccse_country->dump({ok => 1, lines => 5, items => 10, search_key => "Canada"}); # if($DEBUG);
	
	#
	#	Marge amt and ccse, gen rlabr and erc
	#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
	#
	my $ccse_rlavr = $ccse_country->dup();

	foreach my $region (@TARGET_REGION){			# Generate Graph Parameters
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends World Wilde and ccse ern $region", start_date => 0, y2max => 3,
				additional_plot => $additional_plot,
				graph_items => [
				{cdp => $ccse_country, static => "ern",   target_col => {$prov => "", $cntry => $region}, axis => "y2"},
				{cdp => $amt_country,  static => "rlavr", target_col => {region => $region,}},
				],
			},
		));
	}

}

#
#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
if($golist{"amt-jp-pref"}) {
	dp::set_dp_id("amt-jp-pref");
	#
	#	Apple Mobility Trends
	#
	my $AMT_DEF = $defamt::AMT_DEF;
	my $AMT_GRAPH = $defamt::AMT_GRAPH;

	my $amt_cdp = csv2graph->new($AMT_DEF); 										# Init AMD_DEF
	#@{$amt_cdp->{key}} = ("alternative_name", "transportation_type");			# 5, 1, 2
	$amt_cdp->load_csv($AMT_DEF);									# Load to memory
	#$amt_cdp->dump({ok => 1, lines => 5});			# Dump for debug

	$amt_pref = $amt_cdp->reduce_cdp_target({geo_type => $SUBR, country => "Japan"});
	$amt_pref->calc_items("avr", 
				{"transportation_type" => "", "region" => "", "country" => ""},	# All Province/State with Canada, ["*","Canada",]
				{"transportation_type" => "avr", "region" => "="},# total gos ["","Canada"] null = "", = keep
	);
	#calc::comvert2rlavr($amt_pref);							# rlavr for marge with CCSE

	#
	#	Japan Prefecture Data
	# 	year,month,date,prefectureNameJ,prefectureNameE,mainkey
	#	y,m,d,東京,Tokyo,testedPositive,1,2,3,4,
	#	y,m,d,東京,Tokyo,peopleTested,1,2,3,4,
	#
	my $JAPAN_DEF = $defjapan::JAPAN_DEF;
	$JAPAN_DEF->{keys} = ["prefectureNameE"],		# PrefectureNameJ, and Column name
	my $JAPAN_GRAPH = $defjapan::JAPAN_GRAPH;

	my $jp_cdp = csv2graph->new($JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($JAPAN_DEF);
	my $jp_positive = $jp_cdp->reduce_cdp_target({item => "testedPositive"});
 
	foreach my $pref (@TARGET_PREF){			# Generate Graph Parameters
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends Japan and japan ern $pref", start_date => 0, y2max => 3,
				additional_plot => $additional_plot,
				graph_items => [
				{cdp => $jp_positive, static => "ern",   target_col => {prefectureNameE => "$pref"}, axis => "y2"},
				{cdp => $amt_pref,    static => "rlavr", target_col => {country => "Japan", region => "~$pref"},},
				],
			},
		));
	}
}

#
#	Generate Graph
#
#	positive_count,1,2,3,
#	negative_count,1,2,3,
#	positive_rate,1,2,3,
#
if($golist{"tokyo"}){
	dp::set_dp_id("tokyo");
	my $TOKYO_DEF = $deftokyo::TOKYO_DEF;
	my $TOKYO_GRAPH = $deftokyo::TOKYO_GRAPH;
	my $TOKYO_ST_DEF = $deftokyo::TOKYO_ST_DEF;
	my $TOKYO_ST_GRAPH = $deftokyo::TOKYO_ST_GRAPH;

	my $tko_cdp = csv2graph->new($TOKYO_DEF); 						# Load Apple Mobility Trends
	$tko_cdp->load_csv($TOKYO_DEF);
	$tko_cdp->calc_items("sum", 
				{mainkey => "positive_count,negative_count"}, # All Province/State with Canada, ["*","Canada",]
				{mainkey => "tested_count" },# total gos ["","Canada"] null = "", = keep
	);
# 	$tko_cdp->dump({ok => 1, lines => 5, items => 10});               

	my $tko_graph = [];
	push(@$tko_graph, 
		{gdp => $TOKYO_GRAPH, dsc => "Tokyo Postive/negative/rate ", graph => 'line', y2_graph => 'line',
			graph_items => [
				{cdp => $tko_cdp, static => "rlavr", target_col => {mainkey => "positive_count,tested_count"}, graph_def => $box_fill}, 
				{cdp => $tko_cdp, static => "",      target_col => {mainkey => "positive_rate"}, axis => "y2"}, 
				{cdp => $tko_cdp, static => "",      target_col => {mainkey => "positive_count,tested_count"}, graph_def => $line_thin_dot}, 
		]}
	);

	#	hospitalized,1,2,3,
	#	severe_case,1,2,3,
	my $tkost_cdp = csv2graph->new($TOKYO_ST_DEF); 						# Load Apple Mobility Trends
	$tkost_cdp->load_csv($TOKYO_ST_DEF);
	push(@$tko_graph, 
		{gdp => $TOKYO_GRAPH, dsc => "Tokyo Postive staus", graph => 'line', y2_graph => 'line',
			graph_items => [
				{cdp => $tkost_cdp, static => "rlavr", target_col => {mainkey => "hospitalized"}}, 
				{cdp => $tkost_cdp, static => "rlavr", target_col => {mainkey => "severe_case"}, axis => "y2"}, 
				{cdp => $tkost_cdp, static => "",      target_col => {mainkey => "hospitalized"}, graph_def => $line_thin_dot}, 
				{cdp => $tkost_cdp, static => "",      target_col => {mainkey => "severe_case"}, axis => "y2", graph_def => $line_thin_dot}, 
		]}
	);
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(@$tko_graph));
}

#
#	Japan provience information from Tokyo Keizai
# year,month,date,prefectureNameJ,prefectureNameE,testedPositive,peopleTested,hospitalized,serious,discharged,deaths,effectiveReproductionNumber
# 2020,2,8,東京,Tokyo,3,,,,,,
#
#	y,m,d,東京,Tokyo,testedPositive,1,2,3,4,
#	y,m,d,東京,Tokyo,peopleTested,1,2,3,4,
#
#
#
if($golist{japan}){
	dp::set_dp_id("japan");
	my $jp_cdp = csv2graph->new($defjapan::JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($defjapan::JAPAN_DEF);
	#$jp_cdp->dump({ok => 1, lines => 5});			# Dump for debug
	my $jp_rlavr = $jp_cdp->calc_rlavr($jp_cdp);
	my $jp_ern   = $jp_cdp->calc_ern($jp_cdp);
	my $jp_pop   = $jp_cdp->calc_pop($jp_cdp);

	my $jp_graph = [];
	my $positive = "testedPositive";
	my $deaths = "deaths";

	my $target_keys = [$jp_rlavr->select_keys({item => $positive}, 0)];	# select data for target_keys
	my $sorted_keys = [$jp_rlavr->sort_csv(($jp_rlavr->{csv_data}), $target_keys)];
	my $end = min(10, scalar(@$sorted_keys) - 1); 
	dp::dp join(",", @$sorted_keys[0..$end]) . "\n";

	my $ymax = 0;
	my $y2max = 3;

	foreach my $pref (@$sorted_keys[0..$end]) { # "東京都")		data is mainkey ex.東京#testedPositive--conf-rlavr
		$pref =~ s/[-#].*$//;
		foreach my $start_date(0){	#, -93
			my $p = {start_date => $start_date};
			my $jp_pref = $jp_rlavr->reduce_cdp_target({item => $positive, prefectureNameJ => $pref});
			my $y1max = $jp_pref->max_val($p);
			my $y2max = int($y1max * $y2y1rate / 100 + 0.9999999); 
			my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 
			my $death_pref = $jp_rlavr->reduce_cdp_target({item => $deaths, prefectureNameJ => $pref});
			# $death_region->rolling_average();
			my $death_max = $death_pref->max_val($p);

			my $drate = sprintf("%.2f%%", 100 * $death_max / $y1max);
			dp::dp "y1max:$y1max, ymax:$ymax, y2max:$y2max death_max:$death_max\n";

			push(@$jp_graph, 
			{gdp => $defjapan::JAPAN_GRAPH, dsc => "[$pref] new cases and deaths [$drate]", start_date => $start_date, 
				ymax => $ymax, y2max => $y2max, ymin => 0, y2min => 0,
				ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
				#additional_plot => $additional_plot_item{ern}, 
				graph_items => [
				{cdp => $jp_cdp, item => {item => $positive, prefectureNameJ => $pref}, static => "rlavr", graph_def => $line_thick},
				{cdp => $jp_cdp, item => {item => $deaths,   prefectureNameJ => $pref}, static => "rlavr", axis => "y2", graph_def => $box_fill},
				{cdp => $jp_cdp, item => {item => $positive, prefectureNameJ => $pref}, static => "", graph_def => $line_thin_dot,},
				{cdp => $jp_cdp, item => {item => $deaths,   prefectureNameJ => $pref}, static => "", axis => "y2", graph_def => $line_thin_dot},
				],
			},
			{gdp => $defjapan::JAPAN_GRAPH, dsc => "[$pref] new cases and ern", start_date => $start_date, 
				ymax => $ymax, y2max => 3, ymin => 0, y2min => 0,
				additional_plot => $additional_plot_item{ern}, 
				graph_items => [
				{cdp => $jp_cdp, item => {item => $positive, prefectureNameJ => $pref}, static => "rlavr"},
				{cdp => $jp_cdp, item => {item => $positive, prefectureNameJ => $pref}, static => "ern",  axis => "y2"},
				{cdp => $jp_cdp, item => {item => $positive, prefectureNameJ => $pref}, static => "",     graph_def => $line_thin_dot},
				],
			},
			);
##		foreach my $item ($positive, $deaths){
##			push(@$jp_graph, 
##			{gdp => $defjapan::JAPAN_GRAPH, dsc => "Japan [$pref] $item ", start_date => 0, ymin => 0, y2max => 3, graph_items => [
##				{cdp => $jp_cdp, static => "rlavr", target_col => {item => "$item", prefectureNameJ => $pref}}, 
##				{cdp => $jp_cdp, static => "",      target_col => {item => "$item", prefectureNameJ => $pref}, graph_def => $line_thin_dot},
##				{cdp => $jp_cdp, static => "ern",   target_col => {item => "testedPositive", prefectureNameJ => $pref}, axis => "y2"}, 
##			]},
##			);
##			push(@$jp_graph, 
##			{gdp => $defjapan::JAPAN_GRAPH, dsc => "Japan [$pref] pop ", start_date => 0, ymin => 0, y2max => 3, graph_items => [
##				{cdp => $jp_pop, static => "rlavr", target_col => {item => "$item", prefectureNameJ => $pref}}, 
##				{cdp => $jp_pop, static => "",      target_col => {item => "$item", prefectureNameJ => $pref}, graph_def => $line_thin_dot},
##				{cdp => $jp_cdp, static => "ern",   target_col => {item => "testedPositive", prefectureNameJ => $pref}, axis => "y2"}, 
##			]},
##			);
		}
	}
	if(0){
		foreach my $item ("testedPositive", "peopleTested", "hospitalized", "serious", "discharged", "deaths", "effectiveReproductionNumber"){
			foreach my $static ("", "rlavr"){
				my $ymin = ($item eq "effectiveReproductionNumber") ? "" : 0;
				push(@$jp_graph, 
					{gdp => $defjapan::JAPAN_GRAPH, dsc => "Japan $item $static", start_date => 0, ymin => $ymin, graph_items => [
							{cdp => $jp_cdp, static => $static,      target_col => {item => "$item"}},
						#	{cdp => $jp_cdp, static => "rlavr", target_col => {item => "$item"}}, 
						#	{cdp => $jp_positive, static => "ern",   target_col => {prefectureNameE => "$pref"}, axis => "y2"},
					]}
				);
			}
		}
	}
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(@$jp_graph));
}

#
#	Tokyo Weather
#
if($golist{tkow}){
	dp::set_dp_id("tkow");
	my $TKOW_DEF   = $deftkow::TKOW_DEF;
	my $TKOW_GRAPH = $deftkow::TKOW_GRAPH;

	my $tkow_cdp = csv2graph->new($TKOW_DEF); 						# Load Apple Mobility Trends
	$tkow_cdp->load_csv($TKOW_DEF);

	my $tkow_graph = [];
	foreach my $static ("", "rlavr"){
		push(@$tkow_graph, 
			{gdp => $TKOW_GRAPH, dsc => "気温と湿度 $static ", start_date => 0, ymin => 0, 
				graph_items => [
					{cdp => $tkow_cdp, static => $static, target_col => {$mainkey => "~気温"}},
					{cdp => $tkow_cdp, static => $static, target_col => {$mainkey => "~湿度"}, axis => "y2"},
				],
			}
		);
	}
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(@$tkow_graph));
}

#
#
#
if($golist{"tkow-ern"}) {
	dp::set_dp_id("tkow-ern");
	#
	#	Tokyo Weather
	#
	my $tkow_cdp = csv2graph->new($deftkow::TKOW_DEF); 						# Load Apple Mobility Trends
	$tkow_cdp->load_csv($deftkow::TKOW_DEF);

	#
	#	Japan
	#
	my $jp_cdp = csv2graph->new($defjapan::JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($defjapan::JAPAN_DEF);
	$jp_cdp->dump({ok => 1, lines => 5});			# Dump for debug


	my $pref = "東京";
	foreach my $weather ("気温", "湿度"){			# Generate Graph Parameters
		foreach my $static ("ern", "rlavr", ""){
			my $y2max = ($static eq "ern") ? 3 : "";
			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
				{gdp => $deftkow::TKOW_GRAPH, dsc => "Weather and ERN $pref $weather $static", start_date => 0, ymax => "", y2max => $y2max,
					additional_plot => $additional_plot_item{ern},
					graph_items => [
					{cdp => $jp_cdp,  static => $static,   target_col => {prefectureNameJ => "~$pref", item => "testedPositive"}, axis => "y2"},
					{cdp => $tkow_cdp,static => "rlavr", target_col => {$mainkey => "~$weather"},},
					],
				},
			));
		}
	}
}

#
#	Generate HTML FILE
#
#csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
#		row => 1,
#		html_tilte => "COVID-19 related data visualizer ",
#		src_url => "src_url",
#		html_file => "$HTML_PATH/csv2graph_index.html",
#		png_path => $PNG_PATH // "png_path",
#		png_rel_path => $PNG_REL_PATH // "png_rel_path",
#		data_source => "data_source",
#	}
#);

system("./genreport.pl") if($GEN_REPORT);
my $times_cmd = "./htmllist.pl";
#dp::dp "times: $times_cmd\n";
system($times_cmd);
system("ls -lt $HTML_PATH | head -5");

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
