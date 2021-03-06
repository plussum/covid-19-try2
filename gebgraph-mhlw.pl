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

my 	$line_thick = $csv2graph::line_thick;
my	$line_thin = $csv2graph::line_thin;
my	$line_thick_dot = $csv2graph::line_thick_dot;
my	$line_thin_dot = $csv2graph::line_thin_dot;
my	$box_fill = $csv2graph::box_fill;

my $y2y1rate = 2.5;
my $end_target = 0;

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
my @CCSE_TARGET_REGION = (
		"Canada", "Japan", "US", # ,United States",
		"United Kingdom", "France", #"Spain", "Italy", "Russia", 
#			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
#			"Belgium", "Portugal", "Sweden",
#		"India",  "Indonesia", "Israel", # "Iran", "Iraq","Pakistan",
#		"Brazil", "Colombia", "Argentina", "Chile", "Mexico", "Canada", 
#		"South Africa", 
);

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
		"Japan", "US,United States", "India", "Brazil", # ,United States",
		"United Kingdom", "France", "Spain", "Italy", "Russia", 
			"Germany", "Poland", "Ukraine", "Netherlands", "Czechia,Czech Republic", "Romania",
			"Belgium", "Portugal", "Sweden",
		"China", #"Korea- South", 
		"Indonesia", "Israel", # "Iran", "Iraq","Pakistan", different name between amt and ccse  
		"Colombia", "Argentina", "Chile", "Mexico", "Canada", 
		"South Africa", 
);

my @TARGET_PREF = ("Tokyo", "Kanagawa", "Chiba", "Saitama", "Kyoto", "Osaka");

my @cdp_list = ($defamt::AMT_DEF, $defccse::CCSE_DEF, $MARGE_CSV_DEF, 
					$deftokyo::TOKYO_DEF, $defjapan::JAPAN_DEF, $deftkow::TKOW_DEF, $defdocomo::DOCOMO_DEF, $defmhlw::MHLW_DEF); 

my $cmd_list = {"amt-jp" => 1, "amt-jp-pref" => 1, "tkow-ern" => 1, try => 1, "pref-ern" => 1, pref => 1, docomo => 1, upload => 1};

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
	dp::dp "usage:$0 " . join(" | ", "-all", @ids, keys %$cmd_list) ."\n";
	exit;
}
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
		push(@$pd_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date));
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
	foreach my $start_date (0){ # , -28){
		my $sorted_keys = [$jp_rlavr->sort_csv($jp_rlavr->{csv_data}, $target_keys, $start_date, -14)];
		#dp::dp join(",", @$sorted_keys[0..$end]) . "\n";
		my $endt = ($end_target <= 0) ? (scalar(@$sorted_keys) -1) : $end_target;
		dp::dp "#######" . $endt . "\n";
		foreach my $pref (@$sorted_keys[0..$endt]){
			$pref =~ s/[\#\-].*$//;
			dp::dp "$pref\n";
			#push(@$pd_list, &japan_positive_death($jp_cdp, $pref, $start_date));		# 2021.04.05 
			push(@$pd_list, &japan_positive_death_ern($jp_cdp, $pref, $start_date));
		}
	}

	csv2graph->gen_html_by_gp_list($pd_list, {						# Generate HTML file with graphs
			html_tilte => "Positve/Deaths COVID-19 Japan prefecture ",
			src_url => "src_url",
			html_file => "$HTML_PATH/japanpref.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $jp_cdp->{src_info},
		}
	);

}

#
#	CCSE
#
if($golist{ccse}) {
	dp::dp "CCSE\n";
	my $ccse_gp_list = [];
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


	my $graph_kind = $csv2graph::GRAPH_KIND;

	my $start_date = 0;
	my $endt = ($end_target <= 0) ? $#TARGET_REGION : $end_target;
	dp::dp "#######" . $endt . "\n";
	foreach my $region (@TARGET_REGION[0..$endt]){
		dp::dp "$region\n";
		foreach my $start_date(0, -62){
			push(@$ccse_gp_list, &ccse_positive_death_ern($ccse_country, $death_country, $region, $start_date));
		}
		#push(@$ccse_gp_list, &ccse_positive_death($ccse_country, $death_country, $region, 0));
		#push(@$ccse_gp_list, &ccse_positive_ern($ccse_country, $region, 0));
	}
	csv2graph->gen_html_by_gp_list($ccse_gp_list, {						# Generate HTML file with graphs
			html_tilte => "COVID-19 related data visualizer ",
			src_url => "src_url",
			html_file => "$HTML_PATH/ccse.html",
			png_path => $PNG_PATH // "png_path",
			png_rel_path => $PNG_REL_PATH // "png_rel_path",
			data_source => $ccse_cdp->{src_info},
		}
	);
}

#
#
#
if($golist{mhlw}){
	dp::dp "MHLW\n";
	
	my $mhlw_cdp = $defmhlw::MHLW_DEF;
	&{$mhlw_cdp->{down_load}};

	my $gp_list = [];
	my $cdp = csv2graph->new($mhlw_cdp); 						# Load Johns Hopkings University CCSE
	push(@$gp_list, csv2graph->csv2graph_list_gpmix(
	{gdp => $defmhlw::MHLW_DEF, dsc => "MHLW open Data", start_date => 0, 
#		ymax => $ymax, y2max => $y2max, y2min => 0,
#		ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)",
		#additional_plot => $additional_plot_item{ern}, 
		graph_items => [
			{cntrycdp => $cdp,  item => {"item" => "pcr_positive",}, static => "", graph_def => $line_thick},
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
	my($conf_cdp, $death_cdp, $region, $start_date) = @_;

	my $conf_region = $conf_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	my $death_region = $death_cdp->reduce_cdp_target({$prov => "", $cntry => $region});
	return &positive_death_ern($conf_region, $death_region, $region, $start_date, "--conf", "--death");
}

sub	japan_positive_death_ern
{ 
	my($jp_cdp, $pref, $start_date) = @_;

	my $jp_pref = $jp_cdp->reduce_cdp_target({item => $positive, prefectureNameJ => $pref});
	my $death_pref = $jp_cdp->reduce_cdp_target({item => $deaths, prefectureNameJ => $pref});

	return &positive_death_ern($jp_pref, $death_pref, $pref, $start_date, "#testedPositive", "#deaths");
}

sub	positive_death_ern
{
	my($conf_region, $death_region, $region, $start_date, $conf_post_fix, $death_post_fix) = @_;

	#$conf_region->dump();
	#$death_region->dump();
	my $p = {start_date => $start_date};
	my $y1max = $conf_region->max_rlavr($p);
	my $y2max = int($y1max * $y2y1rate / 100 + 0.9999999); 
	my $ymax = csvlib::calc_max2($y1max);			# try to set reasonable max 

	my $death_rlavr = $death_region->calc_rlavr();
	my $death_max = $death_region->max_rlavr($p);

	my $drate = sprintf("%.2f%%", 100 * $death_max / $y1max);
	#dp::dp "y0max:$y0max y1max:$y1max, ymax:$ymax, y2max:$y2max death_max:$death_max\n";

	my $rlavr = $conf_region->calc_rlavr();
	my $ern = $conf_region->calc_ern();
	#$rlavr->dump();
	my $csvp = $ern->{csv_data};
	#my $key = "$region--conf";
	my $key = &search_cdp_key($conf_region, $region, $conf_post_fix);
	dp::dp "[$key]\n";
	if(! $key || !($csvp->{$key}//"")){
		dp::ABORT "$key undefined \n";
		return "";
	}
	my $csv_region = $csvp->{$key};
	my $size = scalar(@$csv_region);
	for(my $i = 0; $i < $size; $i++){
		$csv_region->[$i] = $csv_region->[$i] * $y2max / 3;
		#printf("%.2f ", $csv_pref->[$i]);
	}
	$ern->rename_key($key, "$region-ern");

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
			$dt = "lc 'red' dt (5,5)";
			$title = "title 'ern=$i.0'";
		}
		push(@adp, "$ern axis x1y2 with lines $title lw 1 $dt");
	}

	##
	## POP
	##
	my $pop_key = $key; # $region;
	$pop_key =~ s/$conf_post_fix//;
	#$pop_key =~ s/[-#].*$//;
	#$pop_key =~ s/"//g;
	my $population = $POP{$pop_key};
	if(! defined $POP{$pop_key}){
		dp::ABORT "POP: $pop_key, not defined\n";
		$population = 100000;
	}
	my $pop_100k = int($population / 100000);
	my $pop_max = $ymax / $pop_100k;
	my $pop_last = $rlavr->last_data($key);
	#dp::dp "[$pop_last]\n";
	$pop_last  = sprintf("%.1f", $pop_last / $pop_100k);
	my $pop_dlt = 2.5;
	#dp::dp "$pop_max\n";
	if($pop_max > 15){
		my $pmx = csvlib::calc_max2($pop_max);			# try to set reasonable max 

		my $digit = int(log($pmx)/log(10));
		$digit -- if($digit > 1);
		$pop_dlt =  10**($digit);
		if(($pop_max / $pop_dlt) > 5){
			$pop_dlt *= 2;
		}
		elsif(($pop_max / $pop_dlt) < 3){
			$pop_dlt /= 2;
		}
		#dp::dp "$pop_max, $pmx: $digit : $pop_dlt\n";
	}
	#dp::dp "POP/100k : $region: $pop_100k "  . sprintf("    %.2f", $pop_max) . "\n";
	for(my $i = $pop_dlt; $i < $pop_max; $i +=  $pop_dlt){
		my $pop = $i * $pop_100k;
		my $dt = "lc 'navy' dt (5,5)";
		my $lw = 1;
		if($pop_dlt < 5 && (($i*10) % 10) == 0){
			#$dt =~ s/\(.\)/(5,5)/;
			$dt =~ s/dt.*$//;
			#dp::dp "line: $i, $pop_dlt\n";
		}
		if(($i % 10) == 0){
			$dt =~ s/dt.*$//;
			#$lw = 1.5;
			#dp::dp "line: $i, $pop_dlt\n";
		}
		my $title = sprintf("title 'Positive %.1f/100K'", $i);
		push(@adp, "$pop axis x1y1 with lines $title lw $lw $dt");
	}
	my $add_plot = join(",", @adp);
	$pop_max = sprintf("%.1f", $pop_max);

	#
	#	POP Death
	#
	#my $death_max = $death_region->max_rlavr($p);
#	my @gcl = ("#0070f0", "#e36c09", "forest-green", "dark-violet", 			# https://mz-kb.com/blog/2018/10/31/gnuplot-graph-color/
#				"dark-pink", "#00d0f0", "#60d008", "brown",  "gray50", 
#				);
	my @gcl = ("royalblue", "#e36c09", "forest-green", "mediumpurple3", 			# https://mz-kb.com/blog/2018/10/31/gnuplot-graph-color/
				"dark-pink", "#00d0f0", "#60d008", "brown",  "gray20", 
				"gray30");
	my @bcl = ( "web-blue", "dark-orange",
				"dark-green", "dark-orange");
	my $d100k = 0.5;
	my @death_pop = ();
	my $dn_unit = $pop_100k * $d100k;		# 100deaths / 100K
	my $death_max2 = csvlib::calc_max2($death_max);			# try to set reasonable max 
	my $unit_no = int(0.99999999 + $death_max2 / $dn_unit);
	#my @color = ("forest-green", "web-green");
	my @color = ($bcl[0], $bcl[1]);

	for(my $i = 0; $unit_no <= 1 && $i < 1; $i++){
		#$dn_unit = csvlib::calc_max2($death_max) / 2;			# try to set reasonable max 
		my $rg = $region;
		$rg =~ s/,*$//;
		$d100k /= 5;
		#$d100k = int(200 * $death_max / $pop_100k)/200 ;
		#$d100k = $death_max2 / 2;
		#dp::dp "d100k $d100k, pop100k death_max: $death_max $pop_100k\n";
		$dn_unit = $pop_100k * $d100k;		
		$unit_no = int(0.99999999 + $death_max / $dn_unit);
		@color = ($bcl[2], $bcl[3]);
	}

	dp::dp "death_max: $death_max, pop_100k: $pop_100k, dn_unit: $dn_unit, unit_no: $unit_no\n";
	my $dkey = &search_cdp_key($death_region, $region, $death_post_fix);
	#dp::dp "region:$region dkey[$dkey]\n";
	for(my $i = 0; $i < $unit_no; $i++){
		$death_pop[$i] = $death_rlavr->dup();
		my $du = int($dn_unit * ($i + 1));
		$csvp = $death_pop[$i]->{csv_data}->{$dkey};
		#dp::dp "[$csvp]\n";
		#$death_pop[$i]->dump();
		my $dmax = $death_pop[$i]->{dates};
		#dp::dp "[$i] $du : $death_max:";
		for(my $dt = 0; $dt <= $dmax; $dt++){
			my $v = $csvp->[$dt];
			$csvp->[$dt] = ($v < $du) ? $v: $du;
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
	my $line_thick 	= "line linewidth 2";
	my $line_thin 		= "line linewidth 1" ;
	my $line_thick_dot = "line linewidth 2 dt(7,3)";
	my $line_thin_dot 	= "line linewidth 1 dt(6,4)";
	my $box_fill  		= "boxes fill";

	for(my $i = $unit_no - 1; $i >= 0; $i--){
		my $gn = $i % ($#gtype + 1);
		my $graph_type = $gtype[$gn];
		$graph_type .= " notitle" if($i > 0);
		#dp::dp "gn: $gn, type: " . ($graph_type // "--") . " static\n";
		if($i => $unit_no){
			$death_pop[$i]->rename_key($dkey, sprintf("$dkey-%.2f/100K", $d100k));
			#dp::dp "#" x 40 . "\n";
		}
		push(@$graph_items, 
			{cdp => $death_pop[$i], item => {}, static => "", axis => "y2", graph_def => $graph_type},
		);
	}
	push(@$graph_items, 
			{cdp => $conf_region, item => {}, static => "rlavr", graph_def => ("$line_thick lc rgb \"" . $gcl[3] . "\"")},
			{cdp => $ern,  item => {}, static => "", axis => "y2", graph_def => ("$line_thick_dot lc rgb \"" . $gcl[0] . "\"")},
			{cdp => $conf_region,  item => {}, static => "", graph_def => ("$line_thin_dot lc rgb \"" . $gcl[3] . "\""),},
			{cdp => $death_region, item => {}, static => "", axis => "y2", graph_def => ("$line_thin_dot lc rgb \"" . $color[0] . "\"")},
	);

	my @list = ();
	my $death_last = $death_rlavr->last_data($dkey);
	my $pop_dsc = sprintf("pp[%.1f,%.1f] dp[%.2f,%.2f](max,lst) pop:%d",
		$pop_max, $pop_last, $death_max / $pop_100k, $death_last / $pop_100k, $pop_100k);
	dp::dp "deaths: $death_last, $death_max\n";
	my $rg = $key;
	$rg =~ s/--.*$//;
	$rg =~ s/#.*$//;
	push(@list, csv2graph->csv2graph_list_gpmix(
		{gdp => $defccse::CCSE_GRAPH, dsc => "[$rg] $pop_dsc dr:$drate", start_date => $start_date, 
			ymax => $ymax, y2max => $y2max, y2min => 0,
			ylabel => "confermed", y2label => "deaths (max=$y2y1rate% of rlavr confermed)" ,
			additional_plot => $add_plot,
			graph_items => [@$graph_items],
			no_label_no => 1,
		},
	));
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

#
#
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
if($golist{"amt-jp"}) {

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
if($golist{"amt-ccse"}) {
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
