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
##	CSV_DEF = {
#		title => "Apple Mobility Trends",						# Title of CSV (use for HTML and other)
#		main_url =>  "https://covid19.apple.com/mobility",		# Main URL to reffer
#
#		src_url => $src_url,									# Source URL to download (mainly for HTML)
#		csv_file =>  "$config::WIN_PATH/apm/abc.csv.txt",		# Dowanloaded file, csv file for anlyize
#		down_load => \&download,								# Download function (User must define this)
#
#		timefmt = '%Y-%m-%d',									# 2021-01-02 %Y/%m/%d
#		src_dlm => ",",											# Delimitter (usually "," or "\t")
#		keys => [1, 2],		# 5, 1, 2							# key column numbers  -> Japana-driving
#		data_start => 6,										# Start column number of dates
#
#		#### INITAIL at new
#		csv_data =>  {},										# Main Data (All data of CSV file)
#		date_list =>  [],										# Date information 
#		dates =>  0,											# Number of dates
#		order =>  {},											# Soreted order of data (key)
#		key_items =>  {};
#		avr_date =>  ($CDP->{avr_date} // $DEFAULT_AVR_DATE),
#	};
#
##	GRAPH_PARAMN
#		html_file => "$config::HTML_PATH/apple_mobile.html",	# HTML file to generate
#		html_title => $CSV_DEF->{src_info},						# Use for HTML Title
#		png_path   => "$config::PNG_PATH",						# directory for generating graph items
#		png_rel_path => "../PNG",								# Relative path of CSV, PNG
#		GRAPH_PARAMS = {
#
#		dst_dlm => "\t",										# Delimitter of csv  for gnueplot
#		avr_date => 7,											# Default rolling average term (date)
#	
#		timefmt => '%Y-%m-%d',									# Time format of CSV (gnueplot)
#		format_x => '%m/%d',									# Time format for Graph (gnueplot)
#	
#		term_x_size => 1000,									# Graph image size (x) PNG
#		term_y_size => 350,										# Graph image size (y) PNG
#	
#		END_OF_DATA => $END_OF_DATA,							# END MARK of graph parameters
#		graph_params => [
#			{
#				dsc => "Japan target prefecture", 				# Description of the graph, use for title and file name
#				lank => [1,5], 									# Target data for use (#1 to #5)
#				static => "rlavr", 								# "": Raw, "rlavr":Rolling average
#				start_date => "", 								# Start date: Date format or number (+: from firsta date, -: from last date)
#				end_date => ""									# 	2021-01-01, 10, -10
#				target_col => [ 								### Taget itmes 
#					"sub-region", 								# Col#0 = sub-region
#					"Tokyo,Osaka,Kanagawa",						# Col#1 = Tokyo or Osaka or Kanagawa
#					 "transit", 								# Col#2 = transit
#					"",											# Col#3 = any (*)
#					"",											# Col#4 = any (*)
#					"Japan" 									# Col#5 = Japan
#				],
#			},
#			{dsc => "Japan", lank => [1,99], static => "rlavr", target_col => [@JAPAN], start_date => "", end_date => ""},
#			{dsc => "Japan 2m", lank => [1,99], static => "", target_col => [@JAPAN], start_date => -93, end_date => ""},
#			{dsc => "Japan 2m", lank => [1,99], static => "rlavr", target_col => [@JAPAN], start_date => -93, end_date => ""},
#			{dsc => $END_OF_DATA},
#		}
#	};
#
package csv2graph;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(csv2graph);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use JSON qw/encode_json decode_json/;
use Data::Dumper;
use config;
use csvlib;
use calc;
use load;
use marge;
use reduce;
use select;

use dump;
use util;

binmode(STDOUT, ":utf8");

my $DEBUG = 0;
my $VERBOSE = 0;
my $DEFAULT_AVR_DATE = 7;
my $DEFAULT_KEY_DLM = "-";					# Initial key items
my $DEFAULT_GRAPH = "line";
our $CDP = {};

my $FIRST_DATE = "";
my $LAST_DATE  = "";

#
# Province,Region, Lat, Long, 2021-01-23, 2021-01-24
# ,Japan,33.39,44.12,32,101, 10123, 10124,,,,
# Tokyo,Japan,33.39,44.12,32,20123, 20124,,,,
#
our $cdp_arrays = [
	"date_list", 						# Date list (formated %Y-%m-%d)
	"keys", 							# items to gen key [1, 0] -> Japan#Tokyo, Japan#
	"load_order",						# Load order of the key (Japan#Tokyo, Japan#)
	"item_name_list",					# set by load csv ["Province","Region","Lat","Long"]
	"defined_item_name_list",			# set by user (definition)
	"marge_item_pos",					# Marged key positon
];

our $cdp_hashs = [
	"order",							# sorted order 
	"item_name_hash",					# {"Province" => 0,"Region" => 1,"Lat" => 2,"Long" => 3]
	"alias",							# Set from @defined_item_name_list
	"src_csv",
];

our $cdp_hash_with_keys = [
	"csv_data", 						# csv_data->{Japan#Tokyo}: [10123, 10124,,,,]
	"key_items",						# key_items->{Japan#Tokyo}: ["Tokyo","Japan",33,39],
];

our $cdp_values = [
	"id",								# ID of the definition "ccse", "amt" ,, etc
	"src_info", 						# Description of the data source
	"main_url", 						# main url to reffer
	"src_url", 							# source url of data
	"csv_file",							# CSV(or other) file to be downloaded
	"src_dlm", 							# Delimtter of the data "," or "\t"
	"timefmt", 							# Time format (gnuplot) %Y-%m-%d, %Y/%m/%d, etc
	"data_start",						# Data start colum, ex, 4 : Province,Region, Lat, Long, 2021-01-23, 
	"down_load", 						# Download function
	"dates",							# Number of Date
];

#
#	Default parameters for CSV DEFINITION
#
our $DEFAULT_CSVDEF_PARAMS = {
	id => "now",						# ID of the definition "ccse", "amt" ,, etc
	title => "NAME of DATA FILE", 		# Title(Description) of the definition
	main_url => "MAIN URL of data", 	# main url to reffer
	src_url => "SOURCE URL of data ", 	# source url of data
	csv_file => "",						# CSV(or other) file to be downloaded
	src_dlm => ",", 					# Delimtter of the data "," or "\t"
	dst_dlm => "\t",
	dates => 0,
	avr_date => 7,
	key_dlm => "#",
	timefmt => "%Y-%m-%d", 				# Time format (gnuplot) %Y-%m-%d, %Y/%m/%d, etc
};

#
#	Default parameters for Graph Parameters
#
our $DEFAULT_GRAPHDEF_PARAMS = {
	avr_date => 7,
	timefmt => "%Y-%m-%d", 		# Time format (gnuplot) %Y-%m-%d, %Y/%m/%d, etc
	format_x => '%m/%d',
	term_x_size => 1000,
	term_y_size => 350,
	ylabel => 'COUNT',
	ymin => "",
	ymax => "",
	y2min => "",
	y2max => "", 
	y2label => "",
	y2_source => "",		# soruce csv definition for y2
	additional_plot => "",
	dst_dlm => "\t",
};

#	data_start => "",	# Data start colum, ex, 4 : Province,Region, Lat, Long, 2021-01-23, 
#	down_load => "", 	# Download function
	
# set dump
sub	dump_cdp { return dump::dump_cdp(@_); }
sub dump_key_items { return dump::dump_key_items(@_); } 
sub	dump_csv_data { return dump::dump_csv_data(@_); }

#	Lpad CSV File
sub	load_csv {return load::load_csv(@_);}

#	Reduce
sub	reduce_cdp_target {return reduce::reduce_cdp_target(@_);}
sub	reduce_cdp {return reduce::reduce_cdp(@_);}
sub	dup_cdp {return reduce::dup_cdp(@_);}
sub	dup_csv {return reduce::dup_csv(@_);}

#	Marge
sub	marge_csv{return marge::marge_csv(@_);}

# calc
sub	calc_items {return calc::calc_items(@_);}
sub	rolling_average {return calc::rolling_average(@_);}
sub	comvert2rlavr{return calc::comvert2rlavr(@_);}
sub	comvert2ern {return calc::comvert2ern(@_);}
sub	ern {return calc::ern(@_);}



#
#	inital csv definition
#
sub	new
{
	my ($cdp) = @_;
	
	&init_cdp($cdp);
	return ($cdp);
}

sub	init_cdp
{
	my ($cdp) = @_;
	
	foreach my $item (@$cdp_arrays){
		$cdp->{$item} = [] if(! defined $cdp->{$item});
	}
	foreach my $item (@$cdp_hashs, @$cdp_hash_with_keys){
		$cdp->{$item} = {} if(! defined $cdp->{$item});
	}

	foreach my $k (keys %$DEFAULT_CSVDEF_PARAMS){
		next if(defined $cdp->{$k});
		next if(! defined $DEFAULT_CSVDEF_PARAMS->{$k});

		$cdp->{$k} = $DEFAULT_CSVDEF_PARAMS->{$k};
	}
	#$cdp->{dates} = 0,
	#$cdp->{avr_date} = ($cdp->{avr_date} // $DEFAULT_AVR_DATE),
	#$cdp->{timefmt} = $cdp->{timefmt} // "%Y-%m-%d";
	#$cdp->{key_dlm} = $cdp->{key_dlm} // $DEFAULT_KEY_DLM;
}


#
#	add an item (key) to csv definition
#	$cdp->{csv_data}->{$k}->[1,2,3,4];
#	$cdp->{key_items}->[$k];
#	$cdp->{item_name_list} = [key1, key2, key3]
#	$cdp->{item_name_hash}->{$key} = 0,1,2,3,4,5
#
#
#	defjapan.pm
# 					key,					year,month,date,prefectureNameJ,prefectureNameE
#	(record#0)		Tokyo#testedPositive	2021,1,1,東京,Tokyo,testedPositive 		->{csv_data}
#	(record#1)		Tokyo#deaths			2021,1,1,東京,Tokyo,deathes  			->{csv_data}
#	(record#2)		Osaka#testedPositive	2021,1,1,大阪,Osaka,testedPositive		->{csv_data}
#	(record#3)		Osaka#deaths			2021,1,1,大阪,Osaka,deathes 			->{csv_data}
#
#	date and data of records
#	{date_list}->[2021-01-01, 2021-01-02, 2021-01-03, 2021-01-04, 2021-01-05]	<- {dates} number of dates
# 	{csv_data}->{Tokyo#testedPositive}->[1,2,3,4,5]
#	{csv_data}->{Tokyo#deaths}->[1,2,3,4,5]
#  	{csv_data}->{Osaka#testedPositive}->[1,2,3,4,5]
# 	{csv_data}->{Osaka#deaths}->[1,2,3,4,5]
#
#	keys of records
# 	item_name_list: 0						1,   2,    3,   4,              5,
# 	item_name_hash:	key{0},					year{1},month{2},date{3},prefectureNameJ{4},prefectureNameE{5}
#	{key_items}->{Tokyo#testedPositive}->	[2021,1,1,東京,Tokyo,testedPositive]
#	{key_items}->{Tokyo#deaths}->			[2021,1,1,東京,Tokyo,deathes]
#	{key_items}->{Osaka#testedPositive}->	[2021,1,1,大阪,Osaka,testedPositive]
#	{key_items}->{Osaka#deaths}->			[2021,1,1,大阪,Osaka,deathes]
#
#

#
#	add an key item to csv definition
#
sub	cdp_add_key_items
{
	my ($cdp, $key_names) = @_;
	my $item_name_list = $cdp->{item_name_list};

	if(ref($key_names) ne "ARRAY"){
		my $kn = $key_names;
		$key_names = [$kn];
	}
	my $item_order = scalar(@$item_name_list);
	push(@$item_name_list, @$key_names);		# set item_name 
	foreach my $kn (@$key_names){
		$cdp->{item_name_hash}->{$kn} = $item_order++;
	}
	return 1;
}

#
#	add an item (key) to csv definition
#
sub	cdp_add_record
{
	my ($cdp, $k, $itemp, $dp) = @_;

	$itemp = $itemp // [];
	$dp = $dp // [];
	my $csv_data = $cdp->{csv_data};
	my $key_items = $cdp->{key_items};
	my $load_order = $cdp->{load_order};

	#dp::dp "load_order: $load_order\n";
	$csv_data->{$k} = [@$dp];		# set csv data array
	$key_items->{$k} = [@$itemp];
	push(@$load_order, $k);
}

#
#
#
sub	init_graph_definition_params
{
	my($gdp) = @_;

	foreach my $k (keys %$DEFAULT_GRAPHDEF_PARAMS){
		next if(defined $gdp->{$k});

		$gdp->{$k} = $DEFAULT_GRAPHDEF_PARAMS->{$k};
	}
	return ($gdp);
}

sub	init_graph_params
{
	my($gp, $gdp) = @_;

	foreach my $k (keys %$DEFAULT_GRAPHDEF_PARAMS){
		next if(defined $gp->{$k});

		$gp->{$k} = $gdp->{$k} // $DEFAULT_GRAPHDEF_PARAMS->{$k};
	}
	return($gp);
}

#
#	Set Alias
#
sub	set_alias
{
	my ($cdp, $alias) = @_;

	foreach my $k (keys %$alias){
		my $v = $alias->{$k};
		if($v =~ /\D/){
			if(! defined $cdp->{item_name_hash}){
				dp::WARNING "alias: $v is not defined in item_name_list, $k, $v\n";
				next;
			}
			$v = $cdp->{item_name_hash};
		}
		$cdp->{item_name_hash}->{$k} = $v;
		$cdp->{alias}->{$k} = $v;		# no plan for using, but ...
	}
}

#
#	Generate png, plot-csv.txt, plot-cmv
#
sub	gen_graph_by_list
{
	my($cdp, $gdp, $gp_list) = @_;

	foreach my $gp (@$gp_list){
		&csv2graph($cdp, $gdp, $gp);
		#dp::dp join(",", $gp->{dsc}, $gp->{start_date}, $gp->{end_date},
		#		$gp->{fname}, $gp->{plot_png}, $gp->{plot_csv}, $gp->{plot_cmd}) . "\n";
	}
	return (@{$gdp->{graph_params}});
}

#
#
#
sub gen_html_by_gp_list
{
	my ($graph_params, $p) = @_;

	my $html_title = $p->{html_tilte} // "html_title";
	my $src_url = $p->{src_url} //"src_url";
	my $html_file = $p->{html_file} //"html_file";
	my $png_path = $p->{png_path} //"png_path";
	my $png_rel_path = $p->{png_rel_path} //"png_rel_path";
	my $data_source = $p->{data_source} // "data_source";
	my $dst_dlm = $p->{dst_dlm} // "\t";

	my $CSS = $config::CSS;
	my $class = $config::CLASS;

	csvlib::disp_caller(1..3) if($VERBOSE);
	open(HTML, ">$html_file") || die "Cannot create file $html_file";
	binmode(HTML, ":utf8");

	print HTML "<HTML>\n";
	print HTML "<HEAD>\n";
	print HTML "<TITLE> " . $html_title . "</TITLE>\n";
	print HTML $CSS;
	print HTML "</HEAD>\n";
	print HTML "<BODY>\n";
	my $now = csvlib::ut2d4(time, "/") . " " . csvlib::ut2t(time, ":");

	print HTML "<h3>Data Source：$data_source</h3>\n";

	#dp::dp  "Number of Graph Parameters: " .scalar(@$graph_params) . "\n";
	foreach my $gp (@$graph_params){
		print HTML "<span class=\"c\">$now</span><br>\n";
		print HTML '<img src="' . $png_rel_path . "/" . $gp->{plot_png} . '">' . "\n";
		print HTML "<br>\n";
		#dp::dp "$gp->{plot_png} \n";
	
		#
		#	Lbale name on HTML for search
		#
		my $csv_file = $png_path . "/" . $gp->{plot_csv};
		open(CSV, $csv_file) || die "canot open $csv_file";
		binmode(CSV, ":utf8");

		my $l = <CSV>;		# get label form CSV file
		close(CSV);
		$l =~ s/[\r\n]+$//;
		my @lbl = split($dst_dlm, $l);
		shift(@lbl);

		my $lcount = 10;
		print HTML "<span class=\"c\">\n";
		print HTML "<table>\n<tbody>\n";
		for (my $i = 0; $i < $#lbl; $i += $lcount){
			print HTML "<tr>";
			for(my $j = 0; $j < $lcount; $j++){
				last if(($i + $j) > $#lbl);
				print HTML "<td>" . $lbl[$i+$j] . "</td>";
				#dp::dp "HTML LABEL: " . $lbl[$i+$j] . "\n";
			}
			print HTML "</tr>\n";
		}
		print HTML "</tbody>\n</table>\n";
		print HTML "</span>\n";

		print HTML "<span $class> <a href=\"$src_url\" target=\"blank\"> Data Source (CSV) </a></span>\n";
		#
		#	References
		#
		my @refs = (join(":", "PNG", $png_rel_path . "/" .$gp->{plot_png}),
					join(":", "CSV", $png_rel_path . "/" .$gp->{plot_csv}),
					join(":", "PLT", $png_rel_path . "/" .$gp->{plot_cmd}),
		);
		print HTML "<hr>\n";
		print HTML "<span $class>";
		foreach my $r (@refs){
			my ($tag, $path) = split(":", $r);
			print HTML "$tag:<a href=\"$path\" target=\"blank\">$path</a>\n"; 
		}
		print HTML "<br>\n" ;
		print HTML "</span>\n";
		print HTML "<br><hr>\n\n";
	}
	print HTML "</BODY>\n";
	print HTML "</HTML>\n";
	close(HTML);
}

#
#
#	&gen_html($cdp, $GRAPH_PARAMS);
#
#
sub	gen_html
{
	my ($cdp, $gdp, $gp_list) = @_;

	csvlib::disp_caller(1..3); # if($VERBOSE);
	my $html_file = $gdp->{html_file};
	my $png_path = $gdp->{png_path};
	my $png_rel_path = $gdp->{png_rel_path};
	my $data_source = $cdp->{data_source};
	my $dst_dlm = $gdp->{dst_dlm} // "\t";

	#foreach my $gp (@{$gdp->{graph_params}}){
	foreach my $gp (@$gp_list){
		last if($gp->{dsc} eq ($gdp->{END_OF_DATA}//$config::END_OF_DATA));
		&csv2graph($cdp, $gdp, $gp);
	}
	my $p = {
		src_url => $cdp->{src_url} // "",
		html_title => $gdp->{html_title} // "",
		html_file => $gdp->{html_file} // "",
		png_path => $gdp->{png_path} // "",
		png_rel_path => $gdp->{png_rel_path} // "",
	};
	&gen_html_by_gp_list($gp_list, $p);
}


#
#	Generate Graph and its information but not html file
#
sub	csv2graph_list
{
	my($cdp, $gdp, $graph_params, $verbose) = @_;
	$verbose = $verbose // "";

	if(! (defined $cdp->{id})){
		dp::ABORT "may be you call  csv2graph_list_mix, instead of csv2graph_list\n";
	}
	foreach my $gp (@$graph_params){
		&csv2graph($cdp, $gdp, $gp, $verbose);
	}
	return (@$graph_params);
}

sub	csv2graph_list_mix
{
	my(@gp_list) = @_;

	my @graph_params = ();
	foreach my $gp (@gp_list){
		if(ref($gp) ne "HASH"){
			dp::ABORT "Parameter is not HAS $gp\n";
		}
		if(! (defined $gp->{cdp})){
			dp::ABORT "may be you call  csv2graph_list, instead of csv2graph_list_mix\n";
		}
		last if($gp->{cdp} eq "");

		my $cdp = $gp->{cdp} // dp::ABORT "cdp";
		my $gdp = $gp->{gdp} // dp::ABORT "gdp";
		&csv2graph($cdp, $gdp, $gp, 1);
		push(@graph_params, $gp);
	}

	return (@graph_params);
}

#
#	Generate Graph fro CSV_DATA and Graph Parameters
#
sub	csv2graph
{
	my($cdp, $gdp, $gp, $verbose) = @_;
	$verbose = $verbose // "";
	my $csv_data = $cdp->{csv_data};

	&init_graph_definition_params($gdp);
	&init_graph_params($gp, $gdp);

	#
	#	Set Date Infomation to Graph Parameter
	#
	my $date_list = $cdp->{date_list};
	my $dates = $cdp->{dates};
	#dp::dp "util: $cdp->{id} \n";
	my $start_date = util::date_calc(($gp->{start_date} // ""), $date_list->[0], $cdp->{dates}, $date_list);
	my $end_date   = util::date_calc(($gp->{end_date} // ""),   $date_list->[$dates], $cdp->{dates}, $date_list);
	#dp::dp "START_DATE: $start_date [" . ($gp->{start_date} // "NULL"). "] END_DATE: $end_date [" . ($gp->{end_date}//"NULL") . "]\n";
	$gp->{start_date} = $start_date;
	$gp->{end_date} = $end_date;
	#dp::dp "START_DATE: $start_date [" . ($gp->{start_date} // "NULL"). "] END_DATE: $end_date [" . ($gp->{end_date}//"NULL") . "]\n";
	select::date_range($cdp, $gdp, $gp); 						# Data range (set dt_start, dt_end (position of array)

	#
	#	Set File Name
	#
	my $fname = $gp->{fname} // "";
	if(! $fname){
		$fname = join(" ", $gp->{dsc}, $gp->{static}, $gp->{start_date});
		$fname =~ s/[\/\.\*\ #]/_/g;
		$fname =~ s/\W+/_/g;
		$fname =~ s/__+/_/g;
		$fname =~ s/^_//;
		$gp->{fname} = $fname;
	}
	$gp->{plot_png} = $gp->{plot_png} // "$fname.png";
	$gp->{plot_csv} = $gp->{plot_csv} // "$fname-plot.csv.txt";
	$gp->{plot_cmd} = $gp->{plot_cmd} // "$fname-plot.txt";

	#
	#	select data and generate csv data
	#
	my @target_keys = ();
	my $target_col = $gp->{target_col};
	my $tn = -1;
	if(defined $target_col){
		$tn  = util::array_size($target_col);
		#dp::dp "target_col[$target_col)]($tn)[" . csvlib::join_array(",", $target_col) . "]\n";
	}
	else {
		#dp::dp "target_col[undef]\n";
		$target_col = "";
	}
	if($tn < 0){
		dp::dp "target_col is not array or hash ($target_col) all data will be selected\n";
		csvlib::disp_caller(1..3);
	}

	select::select_keys($cdp, $target_col, \@target_keys, 0);	# select data for target_keys
	#dp::dp "target_key: " . join(" : ", @target_keys). "\n" ;
	#dp::dp "target_col: " . join(" : ", @{$gp->{target_col}}) . "\n";
	if($#target_keys < 0){
		return -1;
	}

	#my %work_csv = ();									# copy csv data to work csv
	#reduce::dup_csv($cdp, \%work_csv, \@target_keys);
	my $work_csv = reduce::dup_csv($cdp, \@target_keys);
	
	if($gp->{static} eq "rlavr"){ 						# Rolling Average
		calc::rolling_average($cdp, $work_csv, $gdp, $gp);
	}
	elsif($gp->{static} eq "ern"){ 						# Rolling Average
		calc::ern($cdp, $work_csv, $gdp, $gp);
	}

	#
	#	Sort target record
	#
	my @lank = ();
	@lank = (@{$gp->{lank}}) if(defined $gp->{lank});
	$lank[0] = 1 if(defined $lank[0] && ! $lank[0]);
	my $lank_select = (defined $lank[0] && defined $lank[1] && $lank[0] && $lank[1]) ? 1 : "";

	my @sorted_keys = ();								# sort
	if($lank_select){
		&sort_csv($cdp, $work_csv, $gp, \@target_keys, \@sorted_keys);
	}
	else {
		my $load_order = $cdp->{load_order};
		@sorted_keys = @$load_order;		# no sort, load Order
	}

	my $order = $cdp->{order};							# set order of key
	my $n = 1;
	foreach my $k (@sorted_keys){
		$order->{$k} = ($lank_select) ? $n : 1;
		$n++;
	}

	#
	#	Genrarte csv file and graph (png)
	#
	my @output_keys = ();
	foreach my $key (@sorted_keys){
		next if($lank_select && ($order->{$key} < $lank[0] || $order->{$key} > $lank[1]));
		push(@output_keys, $key);
	}
	my $csv_for_plot = &gen_csv_file($cdp, $gdp, $gp, $work_csv, \@output_keys);		# Generate CSV File
	#dp::dp "$csv_for_plot\n";

	&graph($csv_for_plot, $cdp, $gdp, $gp);					# Generate Graph
	return @;
}


#
#	Generate CSV File
#
sub	gen_csv_file
{
	my($cdp, $gdp, $gp, $work_csvp, $output_keysp) = @_;
	my $fname = $gp->{fname};
	my $date_list = $cdp->{date_list};
	my $dst_dlm = $gdp->{dst_dlm} // $cdp->{dst_dlm};
	my $dt_start = $gp->{dt_start};
	my $dt_end = $gp->{dt_end};

	#dp::dp "[$dt_start][$dt_end]\n";
	my $csv_for_plot = $gdp->{png_path} . "/" . $gp->{plot_csv}; #"/$fname-plot.csv.txt";
	#dp::dp "### $csv_for_plot\n";
	open(CSV, "> $csv_for_plot") || die "cannot create $csv_for_plot";
	binmode(CSV, ":utf8");

	my $order = $cdp->{order};
	my @csv_label = ();
	foreach my $k (@$output_keysp){
		my $label = join(":", $order->{$k}, $k);
		push(@csv_label, $label);
	}
	print CSV join($dst_dlm, "#date", @csv_label) . "\n";

	for(my $dt = $dt_start; $dt <= $dt_end; $dt++){
		my @w = ();
		foreach my $key (@$output_keysp){
			my $csv = $work_csvp->{$key};
			my $v = $csv->[$dt] // "";
			$v = 0 if($v eq "");
			push(@w, $v);
		}
		if(! defined $date_list->[$dt]){
			dp::dp "### undefined date_list : $dt\n";
		}
		print CSV join($dst_dlm, $date_list->[$dt], @w) . "\n";
	}
	close(CSV);

	return $csv_for_plot;
}

#
#	SORT
#
sub	sort_csv
{
	my ($cdp, $cvdp, $gp, $target_keysp, $sorted_keysp) = @_;
	my $dt_start = $gp->{dt_start};
	my $dt_end = $gp->{dt_end};

	my %SORT_VAL = ();
	my $src_csv = $cdp->{src_csv} // "";
	my $src_csv_count = scalar(keys %$src_csv);
	#dp::dp "sort_csv: " . scalar(@$target_keysp) . "\n";
	foreach my $key (@$target_keysp){
		if(! $key){
			dp::dp "WARING at sort_csv: empty key [$key]\n";
			next;
		}

		my $csv = $cvdp->{$key};
		my $total = 0;
		for(my $dt = $dt_start; $dt <= $dt_end; $dt++){
			my $v = $csv->[$dt] // 0;
			$v = 0 if((!$v) || $v eq "NaN");
			$total += $v ;
		}
		$SORT_VAL{$key} = $total;
		#dp::dp "$key: [$total]\n";
		#if($src_csv && (! defined $src_csv->{$key})){
		if(! defined $src_csv->{$key}){
			$src_csv->{$key} = 0;
			dp::dp "WARING at sort_csv: No src_csv definition for [$key]\n";
		}
	}
	if(! $src_csv){		# Marged CSV
		#dp::dp "--- no src_csv -- $gp->{dsc}\n";
		#csvlib::disp_caller(1..5);
		@$sorted_keysp = (sort {$SORT_VAL{$b} <=> $SORT_VAL{$a}} keys %SORT_VAL);
		#dp::dp "------------" . scalar(@$sorted_keysp) . "\n";
		#dp::dp "------------" . scalar(@$sorted_keysp) . "/" . keys(%SORT_VAL) . "\n";
	}
	else {
		#dp::dp "--- src_csv -- $gp->{dsc} " . ref($src_csv) . "\n";
		foreach my $k (keys %SORT_VAL){
			next if(defined $src_csv->{$k});

			dp::dp "$k is not defined to src_csv\n";
			exit;
		}
		@$sorted_keysp = (sort {($src_csv->{$a}//0) <=> ($src_csv->{$b}//0) 
						or $SORT_VAL{$b} <=> $SORT_VAL{$a}} keys %SORT_VAL);
		#dp::dp "------------" . scalar(@$sorted_keysp) . "/" . keys(%SORT_VAL) . "\n";
	}
}

#
#	Generate Glaph from csv file by gnuplot
#
sub	graph
{
	my($csv_for_plot, $cdp, $gdp, $gp) = @_;

	my $start_date = $gp->{start_date} // "-NONE-";
	my $end_date = $gp->{end_date} // "-NONE-";

	#dp::dp "START_DATE: $start_date END_DATE: $end_date\n";

	my $src_info = $cdp->{src_info} // "";
	if($src_info){
		$src_info = "[$src_info]";
	}
	my $title = join(" ", $gp->{dsc}, $gp->{static}, "($end_date)") . "    $src_info";
	#dp::dp "[$title] $gp->{plot_png}\n";
	#dp::dp "#### " . join(",", "[" . $p->{lank}[0] . "]", @lank) . "\n";

	my $fname = $gdp->{png_path} . "/" . $gp->{fname};
	my $pngf = $gdp->{png_path} . "/" . $gp->{plot_png};# // "$fname.png");
	my $csvf = $gdp->{png_path} . "/" . $gp->{plot_csv} ;#// "$fname-plot.csv.txt");
	my $plotf = $gdp->{png_path} . "/" . $gp->{plot_cmd} ;#// "$fname-plot.txt");
	#my $csvf = $fname . "-plot.csv.txt";
	#my $pngf = $fname . ".png";
	#my $plotf = $fname. "-plot.txt";

	my $dlm = $gdp->{dst_dlm};

	my $time_format = $gdp->{timefmt};
	my $format_x = $gdp->{format_x};
	my $term_x_size = $gdp->{term_x_size};
	my $term_y_size = $gdp->{term_y_size};


	my $start_ut = csvlib::ymds2tm($start_date);
	my $end_ut = csvlib::ymds2tm($end_date);
	my $dates = ($end_ut - $start_ut) / (60 * 60 * 24);
	my $xtics = 60 * 60 * 24 * 7;
	if($dates < 62){
		$xtics = 1 * 60 * 60 * 24;
	}
	elsif($dates < 93){
		$xtics = 2 * 60 * 60 * 24;
	}
	elsif($dates < 120){
		$xtics = 2 * 60 * 60 * 24;
	}

	#dp::dp "ymin: [$gdp->{ymin}]\n";
	my $ymin = $gp->{ymin} // ($gdp->{ymin} // "");
	my $ymax = $gp->{ymax} // ($gdp->{ymax} // "");
	my $yrange = ($ymin ne ""|| $ymax ne "") ? "set yrange [$ymin:$ymax]" : "# yrange";
	my $ylabel = $gp->{ylabel} // ($gdp->{ylabel} // "");
	$ylabel = "set ylabel '$ylabel'"  if($ylabel);

	my $y2min = $gp->{y2min} // ($gdp->{y2min} // "");
	my $y2max = $gp->{y2max} // ($gdp->{y2max} // "");
	my $y2range = ($y2min ne ""|| $y2max ne "") ? "set y2range [$y2min:$y2max]" : "# y2range";
	my $y2label = $gp->{y2label} // ($gdp->{y2label} // "");
	$y2label = ($y2label) ? "set y2label '$y2label'" : "# y2label";
	my $y2tics = "set y2tics";		# Set y2tics anyway

	#
	#	Draw Graph
	#
	my $PARAMS = << "_EOD_";
#!/usr/bin/gnuplot
#csv_file = $csvf
set datafile separator '$dlm'
set xtics rotate by -90
set xdata time
set timefmt '$time_format'
set format x '$format_x'
set mxtics 2
set mytics 2
#set grid xtics ytics mxtics mytics
set key below
set title '$title' font "IPAexゴシック,12" enhanced
#set xlabel 'date'
$ylabel
$y2label
#
set xtics $xtics
set xrange ['$start_date':'$end_date']
set grid
$yrange
$y2range
$y2tics

set terminal pngcairo size $term_x_size, $term_y_size font "IPAexゴシック,8" enhanced
set output '/dev/null'
plot #PLOT_PARAM#
Y_MIN = GPVAL_Y_MIN
Y_MAX = GPVAL_Y_MAX

set output '$pngf'
#ARROW#
plot #PLOT_PARAM#
exit
_EOD_

	#
	#	Gen Plot Param
	#
	my @p= ();
	my $pn = 0;

	#dp::dp "$csvf\n";
	open(CSV, $csvf) || die "cannot open $csvf";
	binmode(CSV, ":utf8");
	my $l = <CSV>;
	close(CSV);
	$l =~ s/[\r\n]+$//;
	my @label = split(/$dlm/, $l);
	dp::dp "CSV: $csvf\n";
	dp::dp "PLOT $plotf\n";
	#dp::dp "### $csvf\n";

	my $src_csv = $cdp->{src_csv} // "";
	#my $y2_source = $gp->{y2_source} // ($gdp->{y2_source} // "");
	my $y2key = $gp->{y2key} // "";
	#dp::dp "soruce_csv[$src_csv] $y2_source\n";
	#$src_csv = "" if($y2_source eq "");
	

	for(my $i = 1; $i <= $#label; $i++){
		my $graph = $gp->{graph} // ($gdp->{graph} // ($cdp->{graph} // $DEFAULT_GRAPH));
		my $y2_graph = "";
		my $key = $label[$i];
		$key =~ s/^[0-9]+://;
		$key =~ s/[']/_/g;	# avoid error at plot
		#dp::dp "### $i: $key $src_csv, $y2key\n";
		$pn++;

		my $axis = "";
		my $dot = "";
		#if($y2_source ne "" && $src_csv ne ""){		#####
		if($y2key ne ""){		#####
			#dp::dp "csv_source: $key [" . $src_csv->{$key} . "]\n";
			#dp::dp "csv_source: $key [" . $src_csv . "]\n";
			$axis =	"axis x1y1";
			#if($src_csv->{$key} == $y2_source) {
			if($y2key && $key =~ /$y2key/) {
				$axis = "axis x1y2" ;
				$dot = "dt (7,3)";
				$graph = $gp->{y2_graph} // ($gdp->{y2_graph} // ($cdp->{y2_graph} // $DEFAULT_GRAPH));
			}
			dp::dp "$key $src_csv->{$key},$y2key: [$axis]\n";
		}
		#dp::dp "axis:[$axis]\n";
		#my $pl = sprintf("'%s' using 1:%d $axis with lines title '%d:%s' linewidth %d $dot", 
		#				$csvf, $i + 1, $i, $label[$i], ($pn < 7) ? 2 : 1);
		
		if($graph =~ /line/){
			$graph .= sprintf(" linewidth %d $dot ", ($pn < 7) ? 2 : 1);
		}
		elsif($graph =~ /box/){
			#dp::dp "BOX\n";
			$graph =~ s/box/box fill/ if(! ($graph =~ /fill/));
		}
		my $pl = sprintf("'%s' using 1:%d $axis with $graph title '%s' ", $csvf, $i + 1, $key);
		push(@p, $pl);
	}
	#push(@p, "0 with lines dt '-' title 'base line'");
	my $additional_plot = $gp->{additional_plot} // ($gdp->{additional_plot} // "");
    if($additional_plot){
        #dp::dp "additional_plot: " . $additional_plot . "\n";
		push(@p, $additional_plot);
    }

	my $plot = join(",", @p);
	$PARAMS =~ s/#PLOT_PARAM#/$plot/g;
	dp::dp $plot . "\n" if($VERBOSE);

	my $date_list = $cdp->{date_list};
	my $dt_start = $gp->{dt_start};
	my $dt_end = $gp->{dt_end};
	#dp::dp join(",", @$date_list) . "\n";
	#dp::dp "###" . join(",", $dt_start, $dt_end, $date_list->[$dt_start], $date_list->[$dt_end], scalar(@$date_list)) . "\n";
	if(1){
		my $RELATIVE_DATE = 7;
		my @aw = ();

		my $den = $gp->{dt_end};
		my $last_date = csvlib::ymds2tm($date_list->[$den]) / (24 * 60 * 60);	# Draw arrow on sunday
		my $s_date = ($last_date - 2) % 7;
		$s_date = 7 if($s_date == 0);
		#dp::dp "DATE: " . $DATES[$date] . "  " . "$date -> $s_date -> " . ($date - $s_date) . "\n";

		#for(my $dn = $gp->{dt_end} - $RELATIVE_DATE; $dn > $gp->{dt_start}; $dn -= $RELATIVE_DATE){
		for(my $dn = $gp->{dt_end} - $s_date; $dn > $gp->{dt_start}; $dn -= $RELATIVE_DATE){
			my $mark_date = $date_list->[$dn];
			
			#dp::dp "ARROW: $dn, [$mark_date]\n";
			my $a = sprintf("set arrow from '%s',Y_MIN to '%s',Y_MAX nohead lw 1 dt (3,7) lc rgb \"dark-red\"",
				$mark_date,  $mark_date);
			push(@aw, $a);
		}
		my $arw = join("\n", @aw);
		#dp::dp "ARROW: $arw\n";
		$PARAMS =~ s/#ARROW#/$arw/;	
	}

	open(PLOT, ">$plotf") || die "cannto create $plotf";
	binmode(PLOT, ":utf8");
	print PLOT $PARAMS;
	close(PLOT);

	#system("cat $plotf");
	#dp::dp "gnuplot $plotf\n";
	system("gnuplot $plotf");
	#dp::dp "-- Done\n";
}
1;
