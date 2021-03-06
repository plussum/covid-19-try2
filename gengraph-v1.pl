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


binmode(STDOUT, ":utf8");

my $VERBOSE = 0;
my $DOWN_LOAD = 0;

my $WIN_PATH = $config::WIN_PATH;
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $DEFAULT_AVR_DATE = 7;
my $END_OF_DATA = "###EOD###";

my $mainkey = $config::MAIN_KEY;

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
my $box_fill  		= "boxes fill";

my $y2y1rate = 2.5;
my $end_target = 0;
my $CCSE_MAX = 119; # 99;

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
		#"France", "Cameroon", 
		#"Australia", "New Zealand",
		"Japan", "US,United States", "India", "Brazil", "Peru",
		"United Kingdom", "France", "Spain", "Italy", "Russia", 
			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
			"Belgium", "Portugal", "Sweden",
		"China", "Taiwan*", "Singapore", "Vietnam", "Malaysia", "Korea-South", 
		"Indonesia", "Israel", # "Iran", "Iraq","Pakistan", different name between amt and ccse  
		"Colombia", "Argentina", "Chile", "Mexico", "Canada", 
		"South Africa", "Seychelles", # ,United States",
		"Australia", "New Zealand",
);

my @TARGET_PREF = ("Tokyo", "Kanagawa", "Chiba", "Saitama", "Kyoto", "Osaka");

my @cdp_list = ($defamt::AMT_DEF, $defccse::CCSE_DEF, $MARGE_CSV_DEF, 
					$deftokyo::TOKYO_DEF, $defjapan::JAPAN_DEF, $deftkow::TKOW_DEF, $defdocomo::DOCOMO_DEF, $defmhlw::MHLW_DEF); 

my $cmd_list = {"amt-jp" => 1, "amt-jp-pref" => 1, "tkow-ern" => 1, try => 1, "pref-ern" => 1, pref => 1, docomo => 1, upload => 1, "ccse-tgt" => 1};
my %REG_INFO = ();

####################################
#
#	Start Main
#
####################################
my %golist = ();
my $all = "";

if($#ARGV >= 0){
	for(my $i = 0; $i <= $#ARGV; $i++){
		$_ = $ARGV[$i];
		if(/-all/){
			$all = 1;
			last;
		}
		if(/^-clear/){
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
		if(/^-et/){
			$end_target = $ARGV[++$i];
			dp::dp "end_target: $end_target\n";
			next;
		}
		if(/^-poplist/){
			print "$config::POPF\n";
			system("cat $config::POPF");
			print "$config::POPF\n";
			exit;
		}
		if($_ eq "try"){
			$golist{pref} = 1;
			$golist{"pref-ern"} = 1;
			$golist{docomo} = 1;
			next;
		}
		if($cmd_list->{$_}){
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

dp::dp join(",", keys %golist) . "\n";
exit;

#if($golist{"amt-ccse"}){
#	$golist{amt} = 1;
#	$golist{ccse} = 1;
#}
if($all){
	foreach my $cdp (@cdp_list){
		my $id = $cdp->{id};
		$golist{$id} = 1 ;
	}
	foreach my $id (keys %$cmd_list){
		$golist{$id} = 1 ;
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

#
#	Try for using 
#
#
if($golist{"pref-ern"}) {
	my $pref_gp_list = [];
	#
	#	ccse Japan
	#
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country

	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	my $graph_kind = $csv2graph::GRAPH_KIND;

	my $region = "Japan";
	foreach my $start_date (0, -93){
		#push(@$pref_gp_list, &ccse_positive_death($ccse_country, $death_country, $region, $start_date));
		push(@$pref_gp_list, &ccse_positive_ern($ccse_country, $region, 0));
	}

	#
	#	Japan Prefectures
	#
	my $jp_cdp = csv2graph->new($defjapan::JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($defjapan::JAPAN_DEF);

	my $jp_rlavr = $jp_cdp->calc_rlavr($jp_cdp);
	my $jp_ern   = $jp_cdp->calc_ern($jp_cdp);
	my $jp_pop   = $jp_cdp->calc_pop($jp_cdp);

	my $positive = "testedPositive";
	my $deaths = "deaths";

	my $target_keys = [$jp_rlavr->select_keys({item => $positive}, 0)];	# select data for target_keys
	foreach my $start_date (0){ # , -28){
		#my $sorted_keys = [$jp_rlavr->sort_csv($jp_rlavr->{csv_data}, $target_keys, $start_date, -14)];
		my $sorted_keys = [$jp_ern->sort_csv($jp_ern->{csv_data}, $target_keys, -7*5, -7*2)];
		my $end = min(50, scalar(@$sorted_keys) - 1); 
		#dp::dp join(",", @$sorted_keys[0..$end]) . "\n";
		foreach my $pref (@$sorted_keys[0..$end]){
			my $csv_data = $jp_cdp->{csv_data};
			my $csvp = $csv_data->{$pref};
			#dp::dp join(", ", $pref, $csv_data, $csvp) . "\n";
			#dp::dp Dumper $csv_data;
			my $size = scalar(@$csvp);
			my $term = 10;
			my $total = 0;
			for(my $i = $size - $term; $i < $size; $i++){
				$total += $csvp->[$i];
			}
			my $avr = $total / $term;
			#dp::dp "$pref: $avr, $total\n";
			$pref =~ s/[\#\-].*$//;
			my $thresh = 5;
			if($avr < $thresh){
				dp::dp "Skip $pref  avr($avr:$total) < $thresh\n";
				next;
			}
			push(@$pref_gp_list, &japan_positive_ern($jp_cdp, $pref, $start_date)) ;
		}
	}

	csv2graph->gen_html_by_gp_list($pref_gp_list, {						# Generate HTML file with graphs
			html_tilte => "ERN/Positive COVID-19 Japan prefecture",
			src_url => "src_url",
			html_file => "$HTML_PATH/japanpref_ern.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $ccse_cdp->{src_info},
		}
	);
}

if($golist{pref}){
	my $pd_list = [];
	my $pd_pop_list = [];

	%REG_INFO = ();
	#
	#	ccse Japan
	#
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country

	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
	my $graph_kind = $csv2graph::GRAPH_KIND;

	my $region = "Japan";
	foreach my $start_date (0, -93){
		#push(@$pd_list, &ccse_positive_death($ccse_country, $death_country, $region, $start_date));
##		push(@$pd_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date));
		#push(@$pd_list, &ccse_positive_ern($ccse_country, $region, 0));
	}

	#
	#	Japan Prefectures
	#
	my $jp_cdp = csv2graph->new($defjapan::JAPAN_DEF); 						# Load Apple Mobility Trends
	$jp_cdp->load_csv($defjapan::JAPAN_DEF);

	my $jp_rlavr = $jp_cdp->calc_rlavr($jp_cdp);
#	my $jp_ern   = $jp_cdp->calc_ern($jp_cdp);
#	my $jp_pop   = $jp_cdp->calc_pop($jp_cdp);

	my $positive = "testedPositive";
	my $deaths = "deaths";
	#
	#	Generate HTML FILE
	#
	my $target_keys = [$jp_rlavr->select_keys({item => $positive}, 0)];	# select data for target_keys
	my $sorted_keys = [$jp_rlavr->sort_csv($jp_rlavr->{csv_data}, $target_keys, -28, 0)];
	my $endt = ($end_target <= 0) ? (scalar(@$sorted_keys) -1) : ($end_target - 1);
	dp::dp "endt : [$endt]\n";
	foreach my $pref (@$sorted_keys[0..$endt]){
		$pref =~ s/[\#\-].*$//;
		dp::dp "rlavr: $pref\n";
		foreach my $start_date (0, -28){ # , -28){
			push(@$pd_list, &japan_positive_death_ern($jp_cdp, $pref, $start_date, 1));		# 0 -> 1 2021.06.28
		}
	}

	my $jp_pop_rlavr   = $jp_rlavr->calc_pop($jp_rlavr);
	$sorted_keys = [$jp_pop_rlavr->sort_csv($jp_pop_rlavr->{csv_data}, $target_keys, -28, 0)];
	foreach my $pref (@$sorted_keys[0..$endt]){
		$pref =~ s/[\#\-].*$//;
		dp::dp "pop: $pref\n";
		foreach my $start_date (0, -28){ # , -28){
			push(@$pd_pop_list, &japan_positive_death_ern($jp_cdp, $pref, $start_date, 1));
		}
	}

	csv2graph->gen_html_by_gp_list($pd_list, {						# Generate HTML file with graphs
			row => 2,
			no_lank_label => 1,
			html_tilte => "Positve/Deaths COVID-19 Japan prefecture ",
			src_url => "src_url",
			html_file => "$HTML_PATH/japanpref.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $jp_cdp->{src_info},
		}
	);
	csv2graph->gen_html_by_gp_list($pd_pop_list, {						# Generate HTML file with graphs
			row => 2,
			no_lank_label => 1,
			html_tilte => "POP Positve/Deaths COVID-19 Japan prefecture ",
			src_url => "src_url",
			html_file => "$HTML_PATH/japanpref_pop.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $jp_cdp->{src_info},
		}
	);

	&gen_reginfo("$HTML_PATH/japanpref_ri_", "nc_pop_last", "nc_pop_max");
	&gen_reginfo("$HTML_PATH/japanpref_ri_", "nc_pop_max", "nc_pop_last");
	&gen_reginfo("$HTML_PATH/japanpref_ri_", "nd_pop_last", "nd_pop_max");
	&gen_reginfo("$HTML_PATH/japanpref_ri_", "nd_pop_max", "nd_pop_last");
	&gen_reginfo("$HTML_PATH/japanpref_ri_", "drate_max");
	&gen_reginfo("$HTML_PATH/japanpref_ri_", "drate_last");
	&gen_reginfo("$HTML_PATH/japanpref_ri_", "nc_week_diff", "nd_week_diff");
	&gen_reginfo("$HTML_PATH/japanpref_ri_", "nd_week_diff", "nc_week_diff");

}

#
#
#
sub	gen_reginfo
{
	my ($outf, $sort_key, @sub) = @_;

	$outf .= $sort_key . ".txt";
	open(OUT, "| nkf -s >$outf") || die "Cannot create $outf";
	binmode(OUT, ":utf8");
	#binmode(OUT, ':encoding(cp932)');
	print OUT "## $sort_key\n";
	my %DISPF = ();
	my @keys_list = ("nc_pop_max", "nc_pop_last", "nd_pop_max", "nd_pop_last", 
					"drate_max", "drate_last", "nc_max", "nd_max", 
					"nc_week_diff", "nd_week_diff",
					"pop_100k",
					);
	my @keys = ();
	foreach my $k ($sort_key, @sub, @keys_list){
		exit if(defined $DISPF{$k});

		$DISPF{$k} = 1;
		push(@keys, $k);
	}
	
	print OUT join("\t", "# region", @keys) . "\n";
	my $n = 1;
	foreach my $region (sort {$REG_INFO{$b}->{$sort_key} <=> $REG_INFO{$a}->{$sort_key}} keys %REG_INFO){
		next if($region =~ /#-/);
		my $r = $REG_INFO{$region};
		$region =~ s/#.*$//;
		$region =~ s/,.*$//;
		$region =~ s/"//;
		$region =~ s/ and /\&/;
		$region =~ s/Republic/Rep./;
		$region =~ s/Herzegovina/Herz./;
		$region =~ s/United Arab Emirates/UAE/;

		my @w = (sprintf("%3d\t%-10s", $n++, $region));
		foreach my $k (@keys){
			my $fmt = "%7.3f";
			$fmt = "%7.1f"  if($k eq "pop_100k");
			$fmt = "%9.2f"  if($k eq "nd_max");
			$fmt = "%11.2f" if($k eq "nc_max");
			push(@w, sprintf($fmt, $r->{$k}));
		}
		$w[0] = "# $w[0]";
		print OUT join("\t", @w) . "\n";
	}
	close(OUT);
}

#
#	CCSE
#
if($golist{"ccse-tgt"}){
	&ccse("ccse-tgt");
}
if($golist{ccse}) {
	&ccse("ccse");
}

sub	ccse
{
	my ($param) = @_;
	%REG_INFO = ();
	dp::dp "CCSE\n";
	my $ccse_gp_list = [];
	my $ccse_rlavr_gp_list = [];
	my $ccse_pop_gp_list = [];

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

	my $graph_kind = $csv2graph::GRAPH_KIND;

	my $ccse_rlavr = $ccse_country->calc_rlavr($ccse_country);
	#$ccse_rlavr->dump({search_key => "Korea"});
	my $target_keys = [$ccse_rlavr->select_keys("", 0)];	# select data for target_keys
	my $sorted_keys = [$ccse_rlavr->sort_csv($ccse_rlavr->{csv_data}, $target_keys, -28, 0)];
	my $target_region = ($param ne "ccse-tgt") ? $sorted_keys  : \@TARGET_REGION;
	my $endt = ($end_target <= 0) ? (scalar(@$target_region) -1) : ($end_target - 1);
	$endt = $CCSE_MAX if($endt > $CCSE_MAX);
	#my $endt = ($end_target <= 0) ? $#TARGET_REGION : $end_target;
	#dp::dp "####### " . $endt . "\n";
	foreach my $region (@$target_region[0..$endt]){
		$region =~ s/--.*//;
		dp::dp "rlavr: $region\n";
		foreach my $start_date(0, -62){
			push(@$ccse_gp_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date, 1));	# 0 -> 1 2021.06.28
			push(@$ccse_rlavr_gp_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date, 0));	# 0 -> 1 2021.06.28
		}
	}

	#my $jp_pop_rlavr   = $jp_rlavr->calc_pop($jp_rlavr);
	#$sorted_keys = [$jp_pop_rlavr->sort_csv($jp_pop_rlavr->{csv_data}, $target_keys, -28, 0)];

	my $ccse_pop_rlavr   = $ccse_rlavr->calc_pop($ccse_rlavr);
	$sorted_keys = [$ccse_pop_rlavr->sort_csv($ccse_pop_rlavr->{csv_data}, $target_keys, -28, 0)];
	$target_region = ($param ne "ccse-tgt") ? $sorted_keys  : \@TARGET_REGION;
	#dp::dp "####### " . $endt . "\n";
	dp::dp "pop:   " . join(",", (@$target_region[0..10])) . "\n";
	foreach my $region (@$target_region[0..$endt]){
		$region =~ s/--.*//;
		dp::dp "pop: $region\n";
		foreach my $start_date(0, -62){
			push(@$ccse_pop_gp_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date, 1));
		}
	}

	csv2graph->gen_html_by_gp_list($ccse_gp_list, {						# Generate HTML file with graphs
			row => 2,
			no_lank_label => 1,
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/$param.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $ccse_cdp->{src_info},
		}
	);
	csv2graph->gen_html_by_gp_list($ccse_rlavr_gp_list, {						# Generate HTML file with graphs
			row => 2,
			no_lank_label => 1,
			html_tilte => "COVID-19 related data visualizer nc-nd ",
			src_url => "src_url",
			html_file => "$HTML_PATH/$param" . "_rlavr.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $ccse_cdp->{src_info},
		}
	);

	csv2graph->gen_html_by_gp_list($ccse_pop_gp_list, {						# Generate HTML file with graphs
			row => 2,
			no_lank_label => 1,
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/$param" . "_pop.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $ccse_cdp->{src_info},
		}
	);

	my $outf = "$param" . "_ri_";
	&gen_reginfo("$HTML_PATH/$outf", "nc_pop_last", "nc_pop_max");
	&gen_reginfo("$HTML_PATH/$outf", "nc_pop_max", "nc_pop_last");
	&gen_reginfo("$HTML_PATH/$outf", "nd_pop_last", "nd_pop_max");
	&gen_reginfo("$HTML_PATH/$outf", "nd_pop_max", "nd_pop_last");
	&gen_reginfo("$HTML_PATH/$outf", "drate_max");
	&gen_reginfo("$HTML_PATH/$outf", "drate_last");
	&gen_reginfo("$HTML_PATH/$outf", "nc_week_diff");
	&gen_reginfo("$HTML_PATH/$outf", "nd_week_diff");
}

#
#	MHLW
#
if($golist{mhlw}){
	dp::dp "MHLW\n";
	
	my $mhlw_cdp = $defmhlw::MHLW_DEF;
	&{$mhlw_cdp->{down_load}};

	my $cdp = csv2graph->new($mhlw_cdp); 						# Load Johns Hopkings University CCSE
	$cdp->load_csv($defmhlw::MHLW_DEF);
	#$cdp->dump();

	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defmhlw::MHLW_GRAPH, dsc => "MHLW open Data", start_date => 0, 
#		ymax => $ymax, y2max => $y2max, y2min => 0,
#		ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
		#additional_plot => $additional_plot_item{ern}, 
		graph_items => [
			{cdp => $cdp,  item => {"item" => "cases",}, static => "", graph_def => $line_thin_dot},
			{cdp => $cdp,  item => {"item" => "cases",}, static => "rlavr", graph_def => $line_thick},
			{cdp => $cdp,  item => {"item" => "pcr_positive",}, static => "", graph_def => $line_thin_dot},
			{cdp => $cdp,  item => {"item" => "pcr_positive",}, static => "rlavr", graph_def => $line_thick},
			{cdp => $cdp,  item => {"item" => "deaths",}, static => "", graph_def => $line_thin_dot, axis => "y2"},
			{cdp => $cdp,  item => {"item" => "deaths",}, static => "rlavr", graph_def => $line_thick, axis => "y2"},
			{cdp => $cdp,  item => {"item" => "pcr_tested_people",}, static => "", graph_def => $line_thin_dot},
			{cdp => $cdp,  item => {"item" => "pcr_tested_people",}, static => "rlavr", graph_def => $line_thin},

		],
	}
	));

	csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/mhlw.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $cdp->{src_info},
		}
	);
}

#
#
#
if($golist{docomo}){
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
if(0){
	foreach my $base (@docomo_base){
		foreach my $static ("", "rlavr"){
			push(@$docomo_gp_list, , csv2graph->csv2graph_list_gpmix(
				{gdp => $defdocomo::DOCOMO_GRAPH, dsc => "docmo $base $static", start_date => $start_date, 
					ymin => "", ymax => "", ylabel => "number", lank => [1,15], label_subs => '#.*$',
					additional_plot => $additional_plot_item{docomo}, 
					graph_items => [
					{cdp => $docomo_cdp, item => {base => $base}, static => "$static", graph_def => $line_thin,},
					# {cdp => $docomo_cdp, item => {base => $base}, static => "", graph_def => $line_thin_dot},
					],
				},
			));
		}
	}
	#my $tokyo_cdp = $docomo_cdp->reduce_cdp_target({base => "~東京"});	# Select Country
	foreach my $base (@docomo_base){
		foreach my $static ("", "rlavr"){
			my $width = 6;
			for(my $n = 1; $n < 12; $n += $width){
				push(@$docomo_gp_list, , csv2graph->csv2graph_list_gpmix(
					{gdp => $defdocomo::DOCOMO_GRAPH, dsc => "Tokyo docmo $base $static $n-" . ($n+$width-1), start_date => $start_date, 
						ymin => "", ymax => "", ylabel => "number", lank => [$n, ($n+$width-1)], label_subs => '#.*$',
						additional_plot => $additional_plot_item{docomo}, 
						graph_items => [
						#{cdp => $docomo_cdp, item => {area => "~東京", base => $base}, static => "$static", graph_def => $line_thin,},
						{cdp => $docomo_cdp, item => {base => $base}, static => "$static", graph_def => $line_thin,},
						# {cdp => $docomo_cdp, item => {base => $base}, static => "", graph_def => $line_thin_dot},
						],
					},
				));
			}
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
	my($conf_cdp, $death_cdp, $region, $start_date, $pop) = @_;

	my $conf_region = $conf_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	my $death_region = $death_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	my $p = "";
	$p = {pop_ymax_nc => 50, pop_ymax_nd => 2} if($pop);

	return &positive_death_ern($conf_region, $death_region, $region, $start_date, "--conf", "--death", $p);
}

sub	japan_positive_death_ern
{ 
	my($jp_cdp, $pref, $start_date, $pop) = @_;

	my $jp_pref = $jp_cdp->reduce_cdp_target({item => $positive, prefectureNameJ => $pref});
	my $death_pref = $jp_cdp->reduce_cdp_target({item => $deaths, prefectureNameJ => $pref});
	my $p = "";
	$p = {pop_ymax_nc => 10, pop_ymax_nd => 0.5} if($pop);

	return &positive_death_ern($jp_pref, $death_pref, $pref, $start_date, "#testedPositive", "#deaths", $p);
}

sub	positive_death_ern
{
	my($conf_region, $death_region, $region, $start_date, $conf_post_fix, $death_post_fix, $p) = @_;

	#$conf_region->dump();
	#$death_region->dump();
	$p = {start_date => $start_date} if(!($p // ""));
	my $pop_ymax_nc = $p->{pop_ymax_nc} // "";
	my $pop_ymax_nd = $p->{pop_ymax_nd} // "";
	dp::dp "[$pop_ymax_nc,$pop_ymax_nd]\n";

	my $nc_max = $conf_region->max_rlavr($p);
	my $nc_max_week = $conf_region->max_rlavr($p);

	my $rlavr = $conf_region->calc_rlavr();
	my $ern = $conf_region->calc_ern();
	my $csvp = $ern->{csv_data};
	my $key = &search_cdp_key($conf_region, $region, $conf_post_fix);
	if(! $key || !($csvp->{$key}//"")){
		dp::ABORT "$key undefined \n";
		return "";
	}

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
		
		$ymax = csvlib::calc_max2($pop_100k * $pop_ymax_nc);
		$y2max = $pop_100k * $pop_ymax_nd;
	}

	my $death_rlavr = $death_region->calc_rlavr();
	my $nd_max = $death_region->max_rlavr($p);

	#my $drate = sprintf("%.2f%%", 100 * $death_max / $nc_max);
	#my $drate = 100 * $death_max / $nc_max;

	#dp::dp "y0max:$y0max nc_max:$nc_max, ymax:$ymax, y2max:$y2max death_max:$nd_max\n";

	#$rlavr->dump();

	my $csv_region = $csvp->{$key};
	my $size = scalar(@$csv_region);
	for(my $i = 0; $i < $size; $i++){
		$csv_region->[$i] = $csv_region->[$i] * $y2max / 3;
		#printf("%.2f ", $csv_pref->[$i]);
	}
	$ern->rename_key($key, "$region-ern");

	#
	#	Lines of ERN
	#
	my @adp = ();
	for(my $i = 0; $i < 3; $i += 0.2){
		next if($i == 0);

		my $ern = sprintf("%.3f", $y2max * $i / 3);
		my $dt = "lc 'royalblue' dt (3,7)";
		my $title = "notitle";
		my $f = int($i * 100) % 100;
		$f = sprintf("%.2f", $i);
		#dp::dp sprintf("ADP: %.5f: %.5f %d", $i,  int($i), $f)  . "\n";
		if($f == int($f)){
			#dp::dp "--> $i\n";
			#$dt = ($i == 1) ? "lc 'red' dt (5,5)" : "lc 'red'";
			$dt = ($i == 1) ? "lc 'red' dt (6,4)" : "lc 'red' dt (3,7)";
			$title = "title 'ern=$i.0'";
		}
		push(@adp, "$ern axis x1y2 with lines $title lw 1 $dt");
	}

	##
	## POP
	##
	#dp::dp "[$pop_key]: $pop_100k\n";
	my $pop_max = $ymax / $pop_100k;
	my $nc_last = $rlavr->last_data($key);
	my $week_pos = -7;
	if($nc_last <= 0){
#		$week_pos--;
#		dp::WARNING "nc_last [$nc_last] $key\n";
#		$nc_last = $rlavr->last_data($key, {end_date => -1});
#		dp::dp "nc_last [$nc_last] $key\n";
		$nc_last = 0.9999; # 1 / ($population * 2));
	}
	my $nc_last_week = $rlavr->last_data($key, {end_date => ($week_pos)});
	#my $nc_last_week = $nc_last;
	#dp::dp "===== nc_last_week: $nc_last_week, $nc_last\n";

	#dp::dp "[$pop_last]\n";
	my $pop_last  = $nc_last / $pop_100k;
	my $pop_dlt = 2.5;
	#dp::dp "$pop_max\n";
	if($pop_max > 15){
		my $pmx = csvlib::calc_max2($pop_max);			# try to set reasonable max 

		my $digit = int(log($pmx)/log(10));
		$digit -- if($digit > 1);
		$pop_dlt =  10**($digit);
		dp::dp sprintf("POL_DLT: %.3f %.3f\n", $pop_dlt, $pop_max / $pop_dlt);
		if(($pop_max / $pop_dlt) >= 5){
			$pop_dlt *= 2;
		}
		elsif(($pop_max / $pop_dlt) < 3){
			$pop_dlt /= 2;
		}
		dp::dp sprintf("POL_DLT: %.3f %.3f\n", $pop_dlt, $pop_max / $pop_dlt);
		#dp::dp "$pop_max, $pmx: $digit : $pop_dlt\n";
	}
	#dp::dp "POP/100k : $region: $pop_100k "  . sprintf("    %.2f", $pop_max) . "\n";
	my $ln = 0;
	for(my $i = $pop_dlt; $i < $pop_max; $i +=  $pop_dlt, $ln++){
		my $pop = $i * $pop_100k;
		my $dt = "lc 'navy' dt (5,5)";
		my $lw = 1;
		#if((($i*10) % 10) == 0){
		if(($ln % 2) == 1){
			$dt =~ s/dt.*$//;
			if(($pop_max / $pop_dlt) < 5 ){
				$lw = 1.5 if(($ln % 2) == 1);
			}
			else {
				$lw = 1.5 if(($ln % 4 ) == 3);
			}
			#$dt =~ s/\(.\)/(5,5)/;
			#dp::dp "line: $i, $pop_dlt\n";
			#dp::dp "====> line: $i, $pop_dlt, $lw $ln\n";
		}
		if(($i % 10) == 0){
			$dt =~ s/dt.*$//;
		}
		#dp::dp "---> line: $i, $pop_dlt, $lw, $ln\n";
		my $title = sprintf("title 'Positive %.1f/100K'", $i);
		push(@adp, "$pop axis x1y1 with lines $title lw $lw $dt");
	}
	my $add_plot = join(",\\\n", @adp);
	#$pop_max = sprintf("%.1f", $pop_max);

	#
	#	POP Death
	#
	#my $nd_max = $death_region->max_rlavr($p);
#	my @gcl = ("#0070f0", "#e36c09", "forest-green", "dark-violet", 			# https://mz-kb.com/blog/2018/10/31/gnuplot-graph-color/
#				"dark-pink", "#00d0f0", "#60d008", "brown",  "gray50", 
#				);
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
	my @death_pop = ();
	my ($d100k, $dn_unit, $unit_no) = ();
	my @color = ();
	my @d100k_list = (0.5, 0.2, 0.1, 0.05, 0.02, 0.01);
	my $rg = $region;
	$rg =~ s/,*$//;
	for(my $i = 0; $i <= $#d100k_list; $i++){
		#$dn_unit = csvlib::calc_max2($nd_max) / 2;			# try to set reasonable max 
		$d100k = $d100k_list[$i];
		$dn_unit = $pop_100k * $d100k;		
		$unit_no = int(0.99999999 + $nd_max / $dn_unit);
		@color = ($bcl[$i*2], $bcl[$i*2+1]);
		#dp::dp "$rg: $d100k : $unit_no $nd_max / $dn_unit " . sprintf("%.2f", $nd_max / $dn_unit) . "\n";
		if(($nd_max / $dn_unit) >= 2.5){
			dp::dp "LAST\n";
			last;
		}
	}
	if($dn_unit < 1){
		$dn_unit = 1 ;
		$unit_no = int(0.99999999 + $nd_max / $dn_unit);
	}


	dp::dp "nd_max: $nd_max, pop_100k: $pop_100k, dn_unit: $dn_unit, unit_no: $unit_no\n";
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
		#dp::dp "[$i] $du0 : $nd_max:";
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
	my $dmax_pop = $nd_max / $pop_100k;
	my $dlst_pop = $nd_last / $pop_100k;
	my $drate_max = 100 * $nd_max / $nc_max;
	my $drate_last = 100 * $nd_last / $nc_last;
	my $pop_dsc = sprintf("pp[%.1f,%.1f] dp[%.2f,%.2f](max,lst) pop:%d",
		$pop_max, $pop_last, $nd_max / $pop_100k, $nd_last / $pop_100k, $pop_100k);
	if($pop_ymax_nc){
		$pop_dsc = sprintf("pop[%d, nc:%.1f, nd:%.1f]", $pop_100k, $pop_ymax_nc, $pop_ymax_nd);
	}
	#dp::dp "===== " .join(",", $region, $nc_last, $nc_last_week,  $nc_last / $nc_last_week) . "\n";
	#dp::dp "===== " .join(",", $region, $nd_last, $nd_last_week,  $nd_last / $nd_last_week) . "\n";
	if($nc_last_week <= 0){
		$nc_last_week = $nc_last / 999;
		dp::dp "====++ " .join(",", $region, $nc_last, $nc_last_week,  $nc_last / $nc_last_week) . "\n";
	}
	if($nd_last_week <= 0){
		$nd_last = 1 if($nd_last == 0);
		$nd_last_week = $nd_last / 999 ;

		dp::dp "====++ " .join(",", $region, $nd_last, $nd_last_week,  $nd_last / $nd_last_week) . "\n";
	}
	my $nc_week_diff = $nc_last / $nc_last_week;
	my $nd_week_diff = $nd_last / $nd_last_week;
	dp::dp "deaths: $nd_last, $nd_max\n";
	#my $rg = $key;
	#$rg =~ s/--.*$//;
	#$rg =~ s/#.*$//;
	my $y2label = ($pop_ymax_nc) ? "deaths" : "deaths (max=$y2y1rate% of rlavr confermed)";
	push(@list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defccse::CCSE_GRAPH, dsc => sprintf("[$rg] $pop_dsc dr:%.2f%%", $drate_max), start_date => $start_date, 
			ymax => $ymax, y2max => $y2max, y2min => 0,
			ylabel => "confermed", y2label => $y2label ,
			additional_plot => $add_plot,
			graph_items => [@$graph_items],
			no_label_no => 1,
		},
	));

	my $reg = "$region#$start_date";
	$REG_INFO{$reg} = {	
			nc_max => sprintf("%.3f", $nc_max), nd_max => sprintf("%.3f", $nd_max), 
			nc_week_diff => sprintf("%.3f", $nc_week_diff), nd_week_diff => sprintf("%.3f", $nd_week_diff), 
			nc_last => sprintf("%.3f", $nc_last), nd_last => sprintf("%.3f", $nd_last), 
			nc_pop_max => sprintf("%.3f", $pop_max), nc_pop_last => sprintf("%.3f", $pop_last), 
			nd_pop_max => sprintf("%.3f", $dmax_pop), nd_pop_last => sprintf("%.3f", $dlst_pop),
			drate_max => sprintf("%.3f", $drate_max) , drate_last => sprintf("%.3f", $drate_last),
			pop_100k => sprintf("%.1f", $pop_100k), 
					};
	return (@list);
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
		{gdp => $defjapan::JAPAN_GRAPH, dsc => "Japan [$pref] new cases and deaths [$drate]", start_date => $start_date, 
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
#
#
if($golist{try00}){
	my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 						# Load Johns Hopkings University CCSE
	$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
	$ccse_cdp->calc_items("sum", 
			{"Province/State" => "", "Country/Region" => "Canada"},				# All Province/State with Canada, ["*","Canada",]
			{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
	);
	$ccse_cdp->calc_items("sum", 
			{"Province/State" => "", "Country/Region" => "China"},				# All Province/State with Canada, ["*","Canada",]
			{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
	);
	my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country

	my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
	$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);
	$death_cdp->calc_items("sum", 
			{"Province/State" => "", "Country/Region" => "Canada"},				# All Province/State with Canada, ["*","Canada",]
			{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
	); 
	$death_cdp->calc_items("sum", 
			{"Province/State" => "", "Country/Region" => "China"},				# All Province/State with Canada, ["*","Canada",]
			{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
	); 
	my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country



if(1){

	foreach my $region (@TARGET_REGION){
		my $ccse_region = $ccse_cdp->reduce_cdp_target({$prov => "NULL", $cntry => $region});
		my $ccse_rlavr = $ccse_region->calc_rlavr();

		#$ccse_rlavr->dump({items => 30});
		my $ccse_pop  = $ccse_rlavr->calc_pop();
		#$ccse_pop->dump({items => 30});
		push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $defccse::CCSE_GRAPH, dsc => "[$region] per population", start_date => 0, ymin => 0, y2min => 0,
				graph_items => [
				{cdp => $ccse_pop,   item => {}, static => "", graph_def => $line_thin_dot,axis => "y2" },
				{cdp => $ccse_rlavr, item => {}, static => "", graph_def => $line_thick, axis => ""},
				#{cdp => $ccse_pop,  item => {$cntry => "$region"}, static => "rlavr", graph_def => $line_thin_dot, },
				],
			})
		);
	}
}
if(1){
	foreach my $region (@TARGET_REGION){
		foreach my $start_date (0, -93){
			my $p = {start_date => $start_date};
			my $conf_region = $ccse_country->reduce_cdp_target({$prov => "", $cntry => $region});
			my $y0max = $conf_region->max_val($p);

			# $conf_region->rolling_average();
			$conf_region = $conf_region->calc_rlavr();
			my $y1max = $conf_region->max_val($p);
			my $y2max = int($y1max * $y2y1rate / 100 + 0.9999999); 
			my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 

			my $death_region = $death_country->reduce_cdp_target({$prov => "", $cntry => $region});
			# $death_region->rolling_average();
			$death_region = $death_region->calc_rlavr();
			my $death_max = $death_region->max_val($p);

			my $drate = sprintf("%.2f%%", 100 * $death_max / $y1max);
			#dp::dp "y0max:$y0max y1max:$y1max, ymax:$ymax, y2max:$y2max death_max:$death_max\n";

			push(@$gp_list, csv2graph->csv2graph_list_gpmix(
			{gdp => $defccse::CCSE_GRAPH, dsc => "[$region] new cases and deaths [$drate]", start_date => $start_date, 
				ymax => $ymax, y2max => $y2max, y2min => 0,
				ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
				#additional_plot => $additional_plot_item{ern}, 
				graph_items => [
				{cdp => $ccse_country,  item => {$cntry => "$region",}, static => "rlavr", graph_def => $line_thick},
				{cdp => $death_country, item => {$cntry => "$region",}, static => "rlavr", axis => "y2", graph_def => $box_fill},
				{cdp => $ccse_country,  item => {$cntry => "$region",}, static => "", graph_def => $line_thin_dot,},
				{cdp => $death_country, item => {$cntry => "$region",}, static => "", axis => "y2", graph_def => $line_thin_dot},
				],
			},
			));
		}
		#last;
	}
}
}

#		{gdp => $AMT_GRAPH, start_date => -92, end_date => "",
#	_mix
#		{gdp => $AMT_GRAPH, start_date => -92, end_date => "",
#			dsc => "Japan Selected focus Pref $dt", lank => [1,10], static => $sts, 
#			graph_item => [
#				{cdp => $amt_pref, staic => "",
#						target_col => {country => "Japan", transportation_type => "average", region => "Japan,USA",}},
#				{cdp => $amt_pref, staic => "rlavr",
#						target_col => {country => "Japan rlavr", transportation_type => "average", region => "Japan,USA",}},
#				{cdp => $amt_pref, staic => "ern", axis => "y2",
#						target_col => {country => "Japan ern", transportation_type => "average", region => "Japan,USA",}},
#				{cdp => $ccse_ern, static => "ern", axis => "y2",
#						target_col => {country => "Japan", transportation_type => "average", region => "Japan,USA",}},
#			],
#		},
#
#
#
if($golist{ccse0})
{
my $ccse_cdp = csv2graph->new($defccse::CCSE_CONF_DEF); 							# Load Johns Hopkings University CCSE
$ccse_cdp->load_csv($defccse::CCSE_CONF_DEF);
$ccse_cdp->calc_items("sum", 
		{"Province/State" => "", "Country/Region" => "Canada"},		# All Province/State with Canada, ["*","Canada",]
		{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
);
$ccse_cdp->calc_items("sum", 
		{"Province/State" => "", "Country/Region" => "China"},		# All Province/State with Canada, ["*","Canada",]
		{"Province/State" => "null", "Country/Region" => "="}		# total gos ["","Canada"] null = "", = keep
);
my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
#$ccse_country->dump({lines => 5, search_key => "China"});
my $ccse_ern = $ccse_country->calc_ern();
my $ccse_pop = $ccse_country->calc_pop(100000);

my $death_cdp = csv2graph->new($defccse::CCSE_DEATHS_DEF); 						# Load Johns Hopkings University CCSE
$death_cdp->load_csv($defccse::CCSE_DEATHS_DEF);
$death_cdp->calc_items("sum", 
		{"Province/State" => "", "Country/Region" => "Canada"},				# All Province/State with Canada, ["*","Canada",]
		{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
);
$death_cdp->calc_items("sum", 
		{"Province/State" => "", "Country/Region" => "China"},				# All Province/State with Canada, ["*","Canada",]
		{"Province/State" => "null", "Country/Region" => "="}				# total gos ["","Canada"] null = "", = keep
);

my $death_country = $death_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
my $death_pop = $death_country->calc_pop(100000);


#
#
#
if(1){
my $width = 5;
my $max_lank = 5;
my $start_date = 0;
for(my $i = 1; $i < $max_lank; $i+= $width){
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defccse::CCSE_GRAPH, dsc => "New Cases $i-" . ($i+$width - 1), start_date => $start_date, 
		lank => [$i, $i + $width -1],
		graph_items => [
		{cdp => $ccse_country,  item => {}, static => "rlavr", },
		#{cdp => $ccse_country,  item => {}, static => "", graph_def => $line_thin_dot},
		],
	}
	));
}
for(my $i = 1; $i <= $max_lank; $i+= $width){
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defccse::CCSE_GRAPH, dsc => "New Cases POP $i-" . ($i+$width - 1), start_date => $start_date, 
		lank => [$i, $i + $width -1],
		graph_items => [
		{cdp => $ccse_pop,  item => {}, static => "rlavr", },
		#{cdp => $ccse_country,  item => {}, static => "", graph_def => $line_thin_dot},
		],
	}
	));
}

for(my $i = 1; $i <= $max_lank; $i+= $width){
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defccse::CCSE_GRAPH, dsc => "New Deaths $i-" . ($i+$width - 1), start_date => $start_date, 
		lank => [$i, $i + $width -1],
		graph_items => [
		{cdp => $death_country,  item => {}, static => "rlavr", },
		#{cdp => $ccse_country,  item => {}, static => "", graph_def => $line_thin_dot},
		],
	}
	));
}
for(my $i = 1; $i <= $max_lank; $i+= $width){
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defccse::CCSE_GRAPH, dsc => "New Deaths POP $i-" . ($i+$width - 1), start_date => $start_date, 
		lank => [$i, $i + $width -1],
		graph_items => [
		{cdp => $death_pop,  item => {}, static => "rlavr", },
		#{cdp => $ccse_country,  item => {}, static => "", graph_def => $line_thin_dot},
		],
	}
	));
}
}
#
#
#
if(1){
my $target_keys = [$ccse_country->select_keys("", 0)];	# select data for target_keys
my $sort_keys = [$ccse_country->sort_csv(($ccse_country->{csv_data}), $target_keys)];
my $end = (scalar(@$sort_keys) < 10) ? scalar(@$sort_keys) : 10; 
dp::dp join(",", @$sort_keys[0..$end]) . "\n";

my @tgl = ("Japan");
foreach my $region (@tgl, @$sort_keys[0..$end]){	 # (@TARGET_REGION)
#dp::dp "$region\n";
$region =~ s/-.*$//;
foreach my $start_date (0) { # , -93){
	my $p = {start_date => $start_date};
	my $conf_region = $ccse_country->reduce_cdp_target({$prov => "NULL", $cntry => $region});

	# $conf_region->rolling_average();
	$conf_region = $conf_region->calc_rlavr();
	my $y1max = $conf_region->max_val($p);
	my $y2max = int($y1max * $y2y1rate / 100 + 0.9999999); 
	my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 

	my $death_region = $death_country->reduce_cdp_target({$prov => "", $cntry => $region});
	# $death_region->rolling_average();
	$death_region = $death_region->calc_rlavr();
	my $death_max = $death_region->max_val($p);

	my $drate = sprintf("%.2f%%", 100 * $death_max / $y1max);
	#dp::dp "y0max:$y0max y1max:$y1max, ymax:$ymax, y2max:$y2max death_max:$death_max\n";

	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defccse::CCSE_GRAPH, dsc => "[$region] new cases and deaths [$drate]", start_date => $start_date, 
		ymax => $ymax, y2max => $y2max, y2min => 0,
		ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
		#additional_plot => $additional_plot_item{ern}, 
		graph_items => [
		{cdp => $ccse_country,  item => {$cntry => "$region",}, static => "rlavr", graph_def => $line_thick},
		{cdp => $death_country, item => {$cntry => "$region",}, static => "rlavr", axis => "y2", graph_def => $box_fill},
		{cdp => $ccse_country,  item => {$cntry => "$region",}, static => "", graph_def => $line_thin_dot,},
		{cdp => $death_country, item => {$cntry => "$region",}, static => "", axis => "y2", graph_def => $line_thin_dot},
		],
	},
	{gdp => $defccse::CCSE_GRAPH, dsc => "[$region] new cases and ern", start_date => 0, y2max => 3,
		ymax => $ymax,
		additional_plot => $additional_plot_item{ern}, 
		graph_items => [
		{cdp => $ccse_country, target_col => {$prov => "", $cntry => "$region"}, static => "rlavr"},
		{cdp => $ccse_ern,     target_col => {$prov => "", $cntry => "$region"}, axis => "y2"},
		{cdp => $ccse_country, target_col => {$prov => "", $cntry => "$region"}, static => "", graph_def => $line_thin_dot},
		],
	},
	));

}
#last;
}
}
##	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
##		{gdp => $defccse::CCSE_GRAPH, dsc => "Japan new cases and ern", start_date => 0, y2max => 3,
##			additional_plot => $additional_plot_item{ern}, 
##			graph_items => [
##			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan"}, static => "rlavr"},
##			{cdp => $ccse_ern, target_col => {$prov => "", $cntry => "Japan"}, axis => "y2"},
##			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan"}, static => "", graph_def => $line_thin_dot},
##			],
##		},
##
##		{gdp => $defccse::CCSE_GRAPH, dsc => "Japan new cases and ern from prov", start_date => 0, y2max => 3,
##			additional_plot => $additional_plot_item{ern}, 
##			graph_items => [
##			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "rlavr"},
##			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "ern", axis => "y2"},
##			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "", graph_def => $line_thin_dot},
##			],
##		},
##		{gdp => $defccse::CCSE_GRAPH, dsc => "Japan new cases and ern from prov 3m", start_date => -91, y2max => 3,
##			additional_plot => $additional_plot_item{ern}, 
##			graph_items => [
##			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "rlavr"},
##			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "ern", axis => "y2"},
##			{cdp => $ccse_country, target_col => {$prov => "", $cntry => "Japan,US",}, static => "", graph_def => $line_thin_dot},
##			],
##		},
##		{gdp => $defccse::CCSE_GRAPH, dsc => "Japan new cases and ern from prov 3m", start_date => 0, y2max => 3,
##			graph_items => [
##			{cdp => $ccse_country, target_col => {$prov => "",}, static => "", lank => [0,5]},
##			],
##		},
##	));
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
		{gdp => $AMT_GRAPH, dsc => "Worldwide Apple Mobility Trends World Wilde", start_date => 0, 
			graph_items => [
			{cdp => $amt_country, item => { transportation_type => "avr"}, static => ""},
			{cdp => $amt_country, item => { transportation_type => "driving"}, static => "", graph_def => $line_thin},
			{cdp => $amt_country, item => { transportation_type => "walking"}, static => "", graph_def => $line_thin},
			{cdp => $amt_country, item => { transportation_type => "transit"}, static => "", graph_def => $line_thin},
			],
		},
		{gdp => $AMT_GRAPH, dsc => "Japan Apple Mobility Trends", start_date => 0, 
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
		{gdp => $AMT_GRAPH, dsc => "Japan Apple Mobility Trends Prefs", start_date => 0, 
			graph_items => [
			{cdp => $amt_pref, static => "", target_col => {country => "Japan", transportation_type => "avr"}, static => "rlavr"},
			],
		},
	));
}

#
#	geo_type,region,transportation_type,alternative_name,sub-region,country,2020-01-13,,,,
#
if($golist{"amt-jp"})
{

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
		foreach my $start (0, -62, -93){
			my $dt = "";
			$dt = "2m" if($start == -62);
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
csv2graph->gen_html_by_gp_list($gp_list, {						# Generate HTML file with graphs
		html_tilte => "COVID-19 related data visualizer ",
		src_url => "src_url",
		html_file => "$HTML_PATH/csv2graph_index.html",
		png_path => $PNG_PATH // "png_path",
		png_rel_path => $PNG_REL_PATH // "png_rel_path",
		data_source => "data_source",
	}
);

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
