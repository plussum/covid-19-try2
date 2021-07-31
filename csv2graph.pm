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
use Clone qw(clone);

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

my $LABEL_DLM = "#DLM#";
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
	"order_list",						# sorted order (keys)
];

our $cdp_hashs = [
	"order",							# sorted order 
	"item_name_hash",					# {"Province" => 0,"Region" => 1,"Lat" => 2,"Long" => 3]
	"alias",							# Set from @defined_item_name_list
];

our $cdp_hash_with_keys = [
	"csv_data", 						# csv_data->{Japan#Tokyo}: [10123, 10124,,,,]
	"key_items",						# key_items->{Japan#Tokyo}: ["Tokyo","Japan",33,39],
	"src_csv",							# source csv ID (,,, may not work ... )
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

our	$line_thick = "#D#line_thick";
our	$line_thin = "#D#line_thin";
our	$line_thick_dot = "#D#line_thick_dot";
our	$line_thin_dot = "#D#line_thin_dot";
our	$box_fill = "#D#box_fill";
our	$box_fill1 = "#D#box_fill1";
our	$box_fill2 = "#D#box_fill2";

our $GRAPH_KIND = {
	$line_thick 	=> "line linewidth 2",
	$line_thin 		=> "line linewidth 1" ,
	$line_thick_dot => "line linewidth 2 dt(7,3)",
	$line_thin_dot 	=> "line linewidth 1 dt(6,4)",
	$box_fill  		=> "boxes fill",
	$box_fill1 		=> 'boxes fill lc rgb "dark-green"',
	$box_fill2 		=> 'boxes fill lc rgb "brown"',
};

#	data_start => "",	# Data start colum, ex, 4 : Province,Region, Lat, Long, 2021-01-23, 
#	down_load => "", 	# Download function
	
# set dump
sub	dump_cdp { return dump::dump_cdp(@_); }
sub	dump{ return dump::dump_cdp(@_); }
sub dump_key_items { return dump::dump_key_items(@_); } 
sub	dump_csv_data { return dump::dump_csv_data(@_); }

#	Lpad CSV File
sub	load_csv {return load::load_csv(@_);}

#	Reduce
sub	reduce_cdp_target {return reduce::reduce_cdp_target(@_);}
sub	reduce_cdp {return reduce::reduce_cdp(@_);}
sub	dup{return reduce::dup(@_);}
sub	dup_csv {return reduce::dup_csv(@_);}

#	Marge
sub	marge_csv{return marge::marge_csv(@_);}

# calc
sub	calc_items {return calc::calc_items(@_);}
sub	calc_method {return calc::calc_method(@_);}
sub	rolling_average {return calc::rolling_average(@_);}
sub	calc_rlavr{return calc::calc_rlavr(@_);}
sub	calc_ern {return calc::calc_ern(@_);}
sub	ern {return calc::ern(@_);}
sub	max_val {return calc::max_val(@_);}
sub	calc_pop {return calc::calc_pop(@_);}
sub	population {return calc::population(@_);}
sub	max_rlavr {return calc::max_rlavr(@_);}
sub	last_data {return calc::last_data(@_);}
sub	gen_total {return calc::calc_record("add", @_);}
sub	calc_record {return calc::calc_record(@_);}

# select
sub	gen_record_key {return select::gen_record_key(@_);} 
sub	gen_key_order {return select::gen_key_order(@_);}
sub	gen_target_col {return select::gen_target_col(@_);}
sub	select_keys {return select::select_keys(@_);}
sub	check_keys {return select::check_keys(@_);}
sub	date_range {return select::date_range(@_);}


#
#	inital csv definition
#
sub	new
{
	#dp::dp "### NEW ####\n";
	my $class = shift;
	my $def  = shift;
	my $self = {};
	if($def//""){
		$self = clone($def);
	}
	#dp::dp Dumper $self;

	#csvlib::disp_caller(1..4);
	&init_cdp($self);
	return bless $self, $class;

#	my ($cdp) = @_;
#	
#	&init_cdp($cdp);
#	return ($cdp);
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
sub	add_key_items
{
	my $self = shift;
	my ($key_names, $label) = @_;

	#
	if(ref($key_names) ne "ARRAY"){
		dp::WARNING "key namses is not ARRAY: $key_names\n";
		my $kn = $key_names;
		$key_names = [$kn];
	}

	#
	#	When label was sat, add new items for exist key_items
	#		The case of calculation, such as rlavr, ern ....
	#
	$label = $label // "ADDED";
	my $keymax = scalar(@$key_names) - 1;
	my $key_items = $self->{key_items};
	foreach my $kn (keys %$key_items){				# set $label[] for all record
		for(my $i = 0; $i <= $keymax; $i++){
			push(@{$key_items->{$kn}}, $label);		# no data for exist record
		}
		#my $new_key = join($self->{dlm}, $key_name, $label);	# change master key seems messsy...
	}
	my $item_name_list = $self->{item_name_list};

	#dp::dp join(",", @$key_names) . "\n";
	my $item_order = scalar(@$item_name_list);
	push(@$item_name_list, @$key_names);		# set item_name 
	foreach my $kn (@$key_names){
		$self->{item_name_hash}->{$kn} = $item_order++;
	}
	#dp::dp "add key : " . join(",", @$item_name_list) . "\n";

	return 1;
}

sub	rename_key
{
	my $self = shift;
	my ($key_name, $new_name) = @_;

	my $csvp = $self->{csv_data};
	foreach my $k (keys %$csvp){
		#dp::dp "[$k]\n";
	}
	if(! ($csvp->{$key_name} // "")){
		dp::WARNING "$key_name is no in the data\n";
		return 1;
	}

	foreach my $item_name ("key_items", "csv_data", "src_csv"){
		#dp::dp "$item_name: $key_name -> $new_name\n";
		$self->{$item_name}->{$new_name} = $self->{$item_name}->{$key_name};
		delete($self->{$item_name}->{$key_name});
	}

	my $load_order = $self->{load_order};
	for(my $i = 0; $i < scalar(@$load_order); $i++){
		if($load_order->[$i] eq $key_name){
			$load_order->[$i] = $new_name;
			last;
		}
	}

	return 0;
}

#
#	add an item (key) to csv definition
#
sub	add_record
{
	my $self = shift;
	my ($k, $itemp, $dp) = @_;

	#csvlib::disp_caller(1..5);
	$itemp = $itemp // [];
	$dp = $dp // [];

	#dp::dp "load_order: $load_order\n";
	$self->{csv_data}->{$k} = [@$dp];		# set csv data array
	$self->{key_items}->{$k} = [@$itemp];
	$self->{src_csv}->{$k} = 0;
	push(@{$self->{load_order}}, $k);

	return 1;
}

#
#	Not checked yet
#
sub	remove_record
{
	my $self = shift;
	my ($k, $itemp, $dp) = @_;

	my $load_order = $self->{load_order};

	delete($self->{csv_data}->{$k}); 
	delete($self->{key_items}->{$k});
	delete($self->{src_csv}->{$k});
	for(my $i = 0; $i < scalar(@$load_order); $i++){
		if($load_order->[$i] eq $k){
			splice(@$load_order, $i, 1);
			last;
		}
	}
	return 1;
}

#
#	Not checked yet
#
sub	remove_data
{
	my $self = shift;

	foreach my $hwk (@$cdp_hash_with_keys){
		undef($self->{$hwk}); 
		$self->{$hwk} = {};
	}
	foreach my $ark ("load_order"){
		undef($self->{$ark});
		$self->{$ark} = [];
	}
	return 1;
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

		$gp->{$k} = $gdp->{$k} // $DEFAULT_GRAPHDEF_PARAMS->{$k} // "";
	}
}

#
#	Set Alias
#
sub	set_alias
{
	my $self = shift;
	my ($alias) = @_;

	foreach my $k (keys %$alias){
		my $v = $alias->{$k};
		if($v =~ /\D/){
			if(! defined $self->{item_name_hash}){
				dp::WARNING "alias: $v is not defined in item_name_list, $k, $v\n";
				next;
			}
			$v = $self->{item_name_hash}->{$v};
		}
		$self->{item_name_hash}->{$k} = $v;
		$self->{alias}->{$k} = $v;		# no plan for using, but ...
	}
	#dp::dp csvlib::join_array(",", $self->{item_name_hash}) . "\n";
	#dp::dp csvlib::join_array(",", $self->{alias}) . "\n";
}

#
#	Generate png, plot-csv.txt, plot-cmv
#
sub	gen_graph_by_list
{
	my $self = shift;
	my($gdp, $gp_list) = @_;

	foreach my $gp (@$gp_list){
		$self->csv2graph($gdp, $gp);
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
	#dp::dp "params:" . csvlib::join_array(",", @_). "\n";
	my ($package, $graph_params, $p) = @_;

	my $html_title = $p->{html_tilte} // "html_title";
	my $src_url = $p->{src_url} //"src_url";
	my $html_file = $p->{html_file} //"html_file";
	my $png_path = $p->{png_path} //"png_path";
	my $png_rel_path = $p->{png_rel_path} //"png_rel_path";
	my $data_source = $p->{data_source} // "data_source";
	my $dst_dlm = $p->{dst_dlm} // "\t";
	my $row = $p->{row} // 1;
	my $no_lank_label = $p->{no_lank_label} // 0;
	my $alt_graph = $p->{alt_graph}//"";

	dp::dp "row: $row\n";
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
	my $graph_no = -1;
	my $row_flash = 0;
	foreach my $gp (@$graph_params){
		next if(! ($gp//""));

		#
		#	Put row
		#
		$graph_no++;

		#dp::dp "######## $graph_no, $row\n";
		#dp::dp "######## " . ($graph_no % $row) . "\n";
		my $rwn = $graph_no % $row;
		if($row > 1){
			if($rwn == 0){
				print HTML "<table>\n<tbody>\n";
				print HTML "<tr><td>\n";
				$row_flash = 1;
			}
		}
		
		#
		#	Get Label Name
		my $csv_file = $png_path . "/" . $gp->{plot_csv};
		open(CSV, $csv_file) || die "canot open $csv_file";
		binmode(CSV, ":utf8");
		my $l = <CSV>;		# get label form CSV file
		close(CSV);
		$l =~ s/[\r\n]+$//;
		my @lbl = split($dst_dlm, $l);
		shift(@lbl);

		my $lcount = 10;

		#
		#	Tag
		#
		my $tag = $gp->{graph_tag} // "UNDEF";
		if($tag eq "UNDEF"){
			$tag = $lbl[0];		#	set tag
			$tag =~ s/\d+:#*//;
			$tag =~ s/#.*//;
			$tag =~ s/--.*//;
		}
		
		print HTML "<a name=\"$tag$rwn\">$tag</a>\n";

		#
		#	Image
		#
		print HTML "<span class=\"c\">$now</span><br>\n";
		print HTML "<a href=\"$alt_graph#$tag" . "0\">" if($alt_graph);
		print HTML '<img src="' . $png_rel_path . "/" . $gp->{plot_png} . '">' . "\n";
		print HTML "</a>\n" if($alt_graph);
		print HTML "<br>\n";
		#dp::dp "$gp->{plot_png} \n";
	
		#
		#	Lbale name on HTML for search
		#

		print HTML "<span class=\"c\">\n";
		print HTML "<table>\n<tbody>\n";
		for (my $i = 0; $i < $#lbl; $i += $lcount){
			print HTML "<tr>";
			for(my $j = 0; $j < $lcount; $j++){
				last if(($i + $j) > $#lbl);
				my $l = $lbl[$i+$j];
				next if($l =~ /notitle/);

				$l =~ s/$LABEL_DLM.*//;
				$l =~ s/^\d+:// if($no_lank_label);
				if($gp->{label_sub_from}){
					my $sub_from = $gp->{label_sub_from};
					my $sub_to = $gp->{label_sub_to} // "";
					#dp::dp "[$sub_from][$sub_to] $l \n";
					$l =~ s/$sub_from/$sub_to/;
				}
				print HTML "<td>" . $l . "</td>";
				#dp::dp "HTML LABEL: " . $lbl[$i+$j] . "\n";
			}
			print HTML "</tr>\n";
		}
		print HTML "</tbody>\n</table>\n";
		print HTML "</span>";

		print HTML "<span $class> <a href=\"$src_url\" target=\"blank\"> Data Source (CSV) </a></span>\n";

		#
		#	References
		#
		my @refs = (join(":", "PNG", $png_rel_path . "/" .$gp->{plot_png}),
					join(":", "CSV", $png_rel_path . "/" .$gp->{plot_csv}),
					join(":", "PLT", $png_rel_path . "/" .$gp->{plot_cmd}),
		);
		print HTML "<span $class>";
		foreach my $r (@refs){
			my ($tag, $path) = split(":", $r);
			print HTML "$tag:<a href=\"$path\" target=\"blank\">$path</a>\n"; 
		}
		print HTML "</span>";

		#
		#	closed
		#
		if($row <= 1){
			print HTML "<br>\n" ;
			print HTML "<br><hr>\n\n";
		}
		else {
			if(($graph_no % $row) == ($row - 1)){
				print HTML "</td></tr>\n";
				print HTML "</tobody></table>\n";

				print HTML "<br>\n" ;
				print HTML "<br><hr>\n\n";
				$row_flash = 0;
			}
			else {
				print HTML "</td><td>\n";
			}
		}
	}
	if($row_flash){
		print HTML "</td></tr>\n";
		print HTML "</tobody></table>\n";

		print HTML "<br>\n" ;
		print HTML "<br><hr>\n\n";
	}
	print HTML "</span>\n";
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
	my $self = shift;
	my ($gdp, $gp_list) = @_;

	csvlib::disp_caller(1..3) if($VERBOSE);
	my $html_file = $gdp->{html_file};
	my $png_path = $gdp->{png_path};
	my $png_rel_path = $gdp->{png_rel_path};
	my $data_source = $self->{data_source};
	my $dst_dlm = $gdp->{dst_dlm} // "\t";

	#foreach my $gp (@{$gdp->{graph_params}}){
	foreach my $gp (@$gp_list){
		last if($gp->{dsc} eq ($gdp->{END_OF_DATA}//$config::END_OF_DATA));
		$self->csv2graph($gdp, $gp);
	}
	my $p = {
		src_url => $self->{src_url} // "",
		html_title => $gdp->{html_title} // "",
		html_file => $gdp->{html_file} // "",
		png_path => $gdp->{png_path} // "",
		png_rel_path => $gdp->{png_rel_path} // "",
	};
	$self->gen_html_by_gp_list($gp_list, $p);
}


#
#	Generate Graph and its information but not html file
#
sub	csv2graph_list
{
	my $self = shift;
	my($gdp, $graph_params, $verbose) = @_;
	$verbose = $verbose // "";

	if(! (defined $self->{id})){
		dp::ABORT "may be you call  csv2graph_list_mix, instead of csv2graph_list\n";
	}
	foreach my $gp (@$graph_params){
		&csv2graph($self, $gdp, $gp, $verbose);
	}
	return (@$graph_params);
}


sub	csv2graph_list_mix
{
	my $package = shift;
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
		$cdp->csv2graph($gdp, $gp, 1);
		push(@graph_params, $gp);
	}

	return (@graph_params);
}

#
#	Generate Graph fro CSV_DATA and Graph Parameters
#
sub	csv2graph
{
	my $self = shift;
	my($gdp, $gp, $verbose) = @_;
	$verbose = $verbose // "";
	my $csv_data = $self->{csv_data};

	#&init_graph_definition_params($gdp);
	&init_graph_params($gp, $gdp);

	#
	#	Set Date Infomation to Graph Parameter
	#
	my $date_list = $self->{date_list};
	my $dates = $self->{dates};
	#dp::dp "util: $self->{id} \n";
	my $start_date = util::date_calc(($gp->{start_date} // ""), $date_list->[0], $self->{dates}, $date_list);
	my $end_date   = util::date_calc(($gp->{end_date} // ""),   $date_list->[$dates], $self->{dates}, $date_list);
	#dp::dp "START_DATE: $start_date [" . ($gp->{start_date} // "NULL"). "] END_DATE: $end_date [" . ($gp->{end_date}//"NULL") . "]\n";
	$gp->{start_date} = $start_date;
	$gp->{end_date} = $end_date;
	#dp::dp "START_DATE: $start_date [" . ($gp->{start_date} // "NULL"). "] END_DATE: $end_date [" . ($gp->{end_date}//"NULL") . "]\n";
	$self->date_range($gdp, $gp); 						# Data range (set dt_start, dt_end (position of array)

	#
	#	Set File Name
	#
	my $fname = $gp->{fname} // "";
	if(! $fname){
		$fname = join(" ", ($gp->{dsc}//"csvgraph"), ($gp->{static}//""), $gp->{start_date});
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
	my $target_keys = [];
	my $target_col = $gp->{target_col} // $gp->{item};
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

	@$target_keys = $self->select_keys($target_col, 0);	# select data for target_keys
	#dp::dp "target_key: " . join(" : ", @$target_keys). "\n" ;
	#dp::dp "target_col: " . join(" : ", @{$gp->{target_col}}) . "\n";
	if(scalar(@$target_keys) <= 0){
		return -1;
	}

	#my %work_csv = ();									# copy csv data to work csv
	#reduce::dup_csv($self, \%work_csv, $target_keys);
	my $work_csv = $self->dup_csv($target_keys);
	
	my $static = $gp->{static} // "";
	if($static eq "rlavr"){ 						# Rolling Average
		$self->rolling_average($work_csv, $gdp, $gp);
	}
	elsif($static eq "ern"){ 						# Rolling Average
		$self->ern($work_csv, $gdp, $gp);
	}
	elsif($static eq "pop"){ 						# Rolling Average
		$self->population($work_csv, $gdp, $gp);
	}

	#
	#	Sort target record
	#
	my @lank = ();
	@lank = (@{$gp->{lank}}) if(defined $gp->{lank});
	$lank[0] = 1 if(defined $lank[0] && ! $lank[0]);
	my $lank_select = (defined $lank[0] && defined $lank[1] && $lank[0] && $lank[1]) ? 1 : "";

	my $sorted_keys = [];								# sort
	if($lank_select){
		@$sorted_keys = $self->sort_csv($work_csv, $target_keys, $gp->{dt_start}, $gp->{dt_end});
	}
	else {
		my $load_order = $self->{load_order};
		@$sorted_keys = @$load_order;		# no sort, load Order
	}

	my $order = $self->{order};							# set order of key
	my $n = 1;
	foreach my $k (@$sorted_keys){
		$order->{$k} = ($lank_select) ? $n : 1;
		$n++;
	}

	#
	#	Genrarte csv file and graph (png)
	#
	my $output_keys = [];
	foreach my $key (@$sorted_keys){
		next if($lank_select && ($order->{$key} < $lank[0] || $order->{$key} > $lank[1]));
		push(@$output_keys, $key);
	}
	my $csv_for_plot = $self->gen_csv_file($gdp, $gp, $work_csv, $output_keys);		# Generate CSV File
	#dp::dp "$csv_for_plot\n";

	$self->graph($csv_for_plot, $gdp, $gp);					# Generate Graph
	return 1;
}

#
#	Generate Graph fro CSV_DATA and Graph Parameters
#
#	Original
#		{cdp => $amt_pref, gdp => $AMT_GRAPH, start_date => $start,
#			dsc => "Japan Selected focus Pref $dt", lank => [1,10], static => $sts, 
#				target_col => {country => "Japan", transportation_type => $AVR, region => "$tgs",}
#		},
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
sub	csv2graph_list_gpmix
{
	my $package = shift;
	my(@gp_mix_list) = @_;
	#my $verbose = $verbose // "";

	#dp::dp join(",", @gp_mix_list) . "\n";
	my $n = 0;
	foreach my $gp_mix (@gp_mix_list){
		#dp::dp "$gp_mix\n";
		&csv2graph_mix("csv2graph", $gp_mix, $n++);
	}
	return (@gp_mix_list);
}

sub	csv2graph_mix
{
	my $package = shift;
	my($gp_mix, $number) = @_;
	#dp::dp join(",", $gp_mix, $number // "") . "\n";
	$number = $number // "";
	
	my $verbose = "";
	my $gdp = $gp_mix->{gdp};
	my $dst_dlm = $gdp->{dst_dlm} // "\t";

	if(defined $gdp->{id} || !defined $gdp->{png_path}){
		dp::WARNING "gdp may wrong, maybe cdp ?\n";
		print Dumper $gdp;
		return 0;
	}

	#
	#	Set File Name
	#
	#my $fname = $gp_mix->{fname} // "";
	my $fname = "";#$gp_mix->{fname} // "";
	if(! $fname){
		#$fname = join(" ", ($gp_mix->{dsc}//"csvgraph"), ($gp_mix->{static}//""), $gp_mix->{start_date});
		$fname = join(" ", ($gp_mix->{dsc}//"csvgraph"), $number, $gp_mix->{start_date});
		$fname =~ s/[\/\.\*\ #]/_/g;
		$fname =~ s/\W+/_/g;
		$fname =~ s/__+/_/g;
		$fname =~ s/^_//;
		$gp_mix->{fname} = $fname;
		#dp::dp "$fname\n";
	}
	$gp_mix->{plot_png} = $gp_mix->{plot_png} // "$fname.png";
	$gp_mix->{plot_csv} = $gp_mix->{plot_csv} // "$fname-plot.csv.txt";
	$gp_mix->{plot_cmd} = $gp_mix->{plot_cmd} // "$fname-plot.txt";

	#dp::dp "fname:: $fname " . join(",", $gp_mix->{plot_png}, $gp_mix->{plot_csv}, $gp_mix->{plot_cmd}) . "\n";
	#
	#	init params 
	#
	my $gp_list = [];
	foreach my $gpp (@{$gp_mix->{graph_items}}){
		#dp::dp "####### " . $gpp->{cdp}->{id} . "\n";
		push(@$gp_list, {%$gpp});
	}
	#dp::dp scalar(@$gp_list) . "\n";

	#
	#	Set CDP 
	#
	foreach my $gpp (@$gp_list){
		my $cdp = $gpp->{cdp} // $gp_mix->{cdp} // dp::ABORT "no CDP defined\n";
		$gpp->{cdp} = $cdp;
		#dp::dp "cdp: " . join(",", $cdp->{id}, $cdp->{dates})  . "\n";
	}

	#
	#	Calc Date 
	#
	my $start_max = "0000-00-00";
	my $end_min   = "9999-99-99";
	foreach my $gpp (@$gp_list){
		my $cdp = $gpp->{cdp};
		my $dates = $cdp->{dates};
		my ($ds, $de) = ($cdp->{date_list}->[0], $cdp->{date_list}->[$dates]);
		$start_max = $ds if($ds gt $start_max);
		$end_min   = $de if($de lt $end_min);
	}
	dp::dp join(",", $start_max, $end_min) . "\n";
	my $start_max_ut = csvlib::ymds2tm($start_max);
	my $end_min_ut = csvlib::ymds2tm($end_min);
	my $dates = ($end_min_ut - $start_max_ut) / (24*60*60);

	#
	#	Error date miss much
	#
	if($dates <= 0){
		dp::WARNING "Date miss much dates=$dates\n";
		dp::dp "max_start, min_end: " . join(",", $start_max, $end_min, $dates) . "\n";
		foreach my $gpp (@$gp_list){
			my $cdp = $gpp->{cdp};
			my ($ds, $de) = ($cdp->{date_list}->[0], $cdp->{date_list}->[$dates]);
			dp::dp $cdp->{id} . ": " . join(",", $ds, $de, $gpp->{date_diff}) . "\n";
		}
		return 0;
	}

	foreach my $gpp (@$gp_list){
		my $cdp = $gpp->{cdp};
		my ($ds, $de) = ($cdp->{date_list}->[0], $cdp->{date_list}->[$dates]);
		$gpp->{date_diff}  = ($start_max_ut - csvlib::ymds2tm($ds)) / (24*60*60);

		#dp::dp $cdp->{id} . ": " . join(",", $ds, $de, $gpp->{date_diff}) . "\n";
	}
	my $gen_dates = int($end_min_ut - $start_max_ut)/(24*60*60);
	my $start_date = util::date_calc(($gp_mix->{start_date} // 0), $start_max, $dates, $start_max);	# 2021-01-01
	my $end_date   = util::date_calc(($gp_mix->{end_date} // $dates),   $end_min, $dates, $start_max);		# 2021-01-02
	#dp::dp "graph_mix:(start_date, end_date, dates) " . join(",", $start_date, $end_date, $dates, $gp_mix->{start_date}) . "\n";

	$gp_mix->{start_date} = $start_date;
	$gp_mix->{end_date} = $end_date;
	$gp_mix->{dt_start} = 0;
	$gp_mix->{dt_end} = $dates;
	#$gp_mix->{dates} = $dates;

	my @lank = (defined $gp_mix->{lank}) ? @{$gp_mix->{lank}} : (1,10); 
	#dp::dp "LANK: " . join(",", @lank) . "\n";
	$lank[0] = $gp_mix->{lank}->[0]//1;	# if(defined $gpp->{lank});
	$lank[0] = 1 if(! $lank[0]);
	$lank[1] = $gp_mix->{lank}->[1]//10; 	#if
	$lank[1] = 10 if(! $lank[1]);
	#dp::dp "LANK: $lank[0], $lank[1]\n";
	my $lank_select = 1; #(defined $lank[0] && defined $lank[1] && $lank[0] && $lank[1]) ? 1 : "";

	#
	#	Gen each data 
	#
	&init_graph_definition_params($gdp);
	my $output_keys = [];
	my $graph_csv = [];
	foreach my $gpp (@$gp_list){
		#my $ccse_country = $ccse_cdp->reduce_cdp_target({"Province/State" => "NULL"});	# Select Country
		my $cdp = clone($gpp->{cdp});
		#my $cdp = $cdp_org->reduce_cdp_target($gpp->{target_col});
		$cdp->dump({ok => 1, lines => 5, items => 10}) if($DEBUG);

		my $csv_data = $cdp->{csv_data};

		&init_graph_params($gpp, $gdp);

		#
		#	Set Date Infomation to Graph Parameter
		#
		$gpp->{start_date} = $start_date;
		$gpp->{end_date} = $end_date;
		$gpp->{dt_start} = 0;
		$gpp->{dt_end} = $dates;
		$cdp->date_range($gdp, $gpp); 			# Data range (set dt_start, dt_end (position of array)

		#
		#	select data and generate csv data
		#
		my $target_keys = [];
		my $target_col = $gpp->{target_col} // $gpp->{item} ;
##		my $tn = -1;
##		if(defined $target_col && $target_col){
##			$tn  = util::array_size($target_col);
##			#dp::dp "target_col[$target_col)]($tn)[" . csvlib::join_array(",", $target_col) . "]\n";
##			if($tn < 0){
##				dp::dp "target_col is not array or hash ($target_col) all data will be selected\n";
##				csvlib::disp_caller(1..3);
##			}
##		}
##		else {
##			#dp::dp "target_col[undef]\n";
##			$target_col = "";
##		}

		#dp::dp "#### ". Dumper($target_col);
		@$target_keys = $cdp->select_keys($target_col, 0);	# select data for target_keys

		#dp::dp "target_key: " . join(" : ", @$target_keys). "\n" ;
		#dp::dp "target_col: " . join(" : ", @{$gpp->{target_col}}) . "\n";
		if(scalar(@$target_keys) <= 0){
			dp::WARNING "no taget data \n";
			return -1;
		}

		my $static = $gpp->{static} // "";
		if($static eq "rlavr"){ 						# Rolling Average
			$cdp->rolling_average($cdp->{csv_data}, $gdp, $gpp);
		}
		elsif($static eq "ern"){ 						# Rolling Average
			$cdp->ern($cdp->{csv_data}, $gdp, $gpp);
		}

		#
		#	Sort target record
		#
		my $sorted_keys = [];								# sort
		if($lank_select){
			my $dt_start = $gp_mix->{sort_start} // 0;
			$dt_start =  &csv_size($cdp->{csv_data}) if($dt_start eq "\$");
			my $dt_end = $gp_mix->{sort_end} // $dates;
			@$sorted_keys = $cdp->sort_csv($cdp->{csv_data}, $target_keys, $dt_start, $dt_end);
		}
		else {
			my $load_order = $cdp->{load_order};
			@$sorted_keys = @$load_order;		# no sort, load Order
		}

		my $order = $cdp->{order};							# set order of key
		my $n = 1;
		foreach my $k (@$sorted_keys){
			$order->{$k} = ($lank_select) ? $n : 1;
			$n++;
		}

		#
		#	Genrarte csv file and graph (png)
		#
		my $start_date_tm = csvlib::ymds2tm($start_date) + $gpp->{date_diff};
		my $diff = $gpp->{date_diff};
		my $subs = $gp_mix->{label_subs} // "";
		foreach my $key (@$sorted_keys){
			my $order = $order->{$key};
			next if($lank_select && ($order < $lank[0] || $order > $lank[1]));
			
			#dp::dp "order: $key -> $order->{$key}\n";
			my $wk = ($static) ? "$key-$static" : $key;
			$wk =~ s/$subs// if($subs);
			#dp::dp "$wk <- $key $subs\n";
			my @csv_data = @{$cdp->{csv_data}->{$key}};
			my $lbl = join($LABEL_DLM, ("$order:$wk"), ($gpp->{axis}//""), ($gpp->{graph_def}//""));
			push(@$graph_csv, [$lbl, @csv_data[$diff..($diff+$dates)]]);
			#dp::dp "$diff, $dates , " . join(",", @{$graph_csv->[scalar(@$graph_csv) - 1]}). "\n";
		}
	}

	#
	#	Gen CSV File
	#
	#dp::dp "PNG_PATH: " . $gdp->{png_path} . "\n";
	my $csv_for_plot = $gdp->{png_path} . "/" . $gp_mix->{plot_csv}; #"/$fname-plot.csv.txt";
	#dp::dp "### $csv_for_plot\n";

	open(CSV, "> $csv_for_plot") || die "cannot create $csv_for_plot";
	binmode(CSV, ":utf8");

	my @w = ();
	for(my $item = 0; $item < scalar(@$graph_csv); $item++){
		push(@w, $graph_csv->[$item]->[0]);
	}
	print CSV join($dst_dlm, "#date", @w) . "\n";

	my $graph_cdp = {
		src_info => $gdp->{html_title},
		date_list => [],
		dates => $dates,
		src_csv => "",
	};
	#dp::dp "#############################\n";
	#my $graph_cdp = csv2graph::new("csv2graph", $cdp_info );
	#dp::dp "graph_csv: " . scalar(@$graph_csv) . "\n";
	
	for(my $dt = 0; $dt <= $dates; $dt++){
		my $date = csvlib::ut2date($start_max_ut + $dt * 24*60*60);
		$graph_cdp->{date_list}->[$dt] = $date;
		my @vals = ();
		for(my $item = 0; $item < scalar(@$graph_csv); $item++){
			my $v = $graph_csv->[$item]->[$dt+1];
			$v = $v//-999;
			push(@vals, $v);
			#dp::dp "$item, $dt, $v\n";
		}
		print CSV join($dst_dlm, $date, @vals) . "\n";
	}
	close(CSV);
	csv2graph::graph($graph_cdp, $csv_for_plot, $gdp, $gp_mix);					# Generate Graph
	return 1;
}


#
#	Genrate CSV file 
#
sub	gen_csv_file
{
	my $self = shift;
	my($gdp, $gp, $work_csvp, $output_keysp) = @_;
	my $fname = $gp->{fname};
	my $date_list = $self->{date_list};
	my $dst_dlm = $gdp->{dst_dlm} // $self->{dst_dlm};
	my $dt_start = $gp->{dt_start};
	my $dt_end = $gp->{dt_end};

	#dp::dp "[$dt_start][$dt_end]\n";
	my $csv_for_plot = $gdp->{png_path} . "/" . $gp->{plot_csv}; #"/$fname-plot.csv.txt";
	#dp::dp "### $csv_for_plot\n";
	open(CSV, "> $csv_for_plot") || die "cannot create $csv_for_plot";
	binmode(CSV, ":utf8");

	my $order = $self->{order};
	my @csv_label = ();
	foreach my $k (@$output_keysp){
		my $label = join(":", $order->{$k}, $k);
		#my $label = $k;
		#dp::dp $label . "\n";
		push(@csv_label, $label);
	}
	print CSV join($dst_dlm, "#date", @csv_label) . "\n";

	for(my $dt = $dt_start; $dt <= $dt_end; $dt++){
		my @w = ();
		foreach my $key (@$output_keysp){
			my $csv = $work_csvp->{$key};
			my $v = $csv->[$dt] // "";
			$v = 0 if($v eq "");
			$v = sprintf("%.2f", $v);
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

sub	csv_size
{
	my ($csvp) = @_;

	foreach my $k (keys %$csvp){
		my $sz = scalar(@{$csvp->{$k}});
		return $sz - 1;
	}
	return -1;
}

#
#	SORT
#
sub	sort_csv
{
	my $self = shift;
	my ($csvp, $target_keysp, $dt_start, $dt_end) = @_;
	
	#dp::dp "($dt_start, $dt_end)\n";
	#csvlib::disp_caller(0..3);
	#dp::dp "$csvp\n";

	$dt_start = ($dt_start//"") ? $dt_start : 0;
	$dt_end = ($dt_end//"") ? $dt_end : &csv_size($csvp);		# 2021.03.15
	if($dt_start < 0){											# 2021.03.15
		$dt_start = &csv_size($csvp) + $dt_start;						# 2021.03.15
	}															# 2021.03.15
	if($dt_end <= 0){											# 2021.03.15
		$dt_end = &csv_size($csvp) + $dt_end;					# 2021.03.15
	}															# 2021.03.15
	#dp::dp "sort [$dt_start, $dt_end] " . &csv_size($csvp) . "\n";
	#my $dt_start = $gp->{dt_start};
	#my $dt_end = $gp->{dt_end};

	my $sorted_keysp = [];
	my %SORT_VAL = ();
	my $src_csv = $self->{src_csv} // "";
	my $src_csv_count = scalar(keys %$src_csv);
	#dp::dp "sort_csv ($src_csv): " . scalar(@$target_keysp) . "\n";
	#print Dumper $src_csv;
	foreach my $key (@$target_keysp){
		$dt_end = scalar(@{$csvp->{$key}} - 1) if(! $dt_end);
		if(! $key){
			dp::dp "WARING at sort_csv: empty key [$key]\n";
			next;
		}

		my $csv = $csvp->{$key};
		my $total = 0;
		for(my $dt = $dt_start; $dt <= $dt_end; $dt++){
			my $v = $csv->[$dt] // 0;
			$v = 0 if((!$v) || $v eq "NaN");
			$total += $v ;
		}
		$total = 10 ** 20  - 1 if($total eq "Inf");		# for avoiding error at sort
		$total = 0  if($total eq "NaN");				# for avoiding error at sort
		$SORT_VAL{$key} = $total;
		#dp::dp "$key:($dt_start - $dt_end) [$total]\n";
		#if($src_csv && (! defined $src_csv->{$key})){
		if(! defined $src_csv->{$key}){
			$src_csv->{$key} = 0;
			dp::dp "WARING at sort_csv: No src_csv definition for [$key]\n";
		}
	}
	if(! $src_csv){		# Marged CSV
		dp::dp "--- no src_csv -- \n";
		#csvlib::disp_caller(1..5);
		@$sorted_keysp = (sort {$SORT_VAL{$b} <=> $SORT_VAL{$a}} keys %SORT_VAL);
		#dp::dp "------------" . scalar(@$sorted_keysp) . "\n";
		#dp::dp "------------" . scalar(@$sorted_keysp) . "/" . keys(%SORT_VAL) . "\n";
	}
	else {
		#dp::dp "--- src_csv --  " . ref($src_csv) . "\n";
		foreach my $k (keys %SORT_VAL){
			#dp::dp "$k: $SORT_VAL{$k}\n";
			next if((defined $src_csv->{$k}) && (defined $SORT_VAL{$k}));
			dp::dp "$k is not defined to src_csv or SORT_VAL\n";
		}
		#@$sorted_keysp = (sort {($src_csv->{$a}//0) <=> ($src_csv->{$b}//0) 
		#				or ($SORT_VAL{$b}//0) <=> ($SORT_VAL{$a}//0)} keys %SORT_VAL);
		@$sorted_keysp = (sort {$SORT_VAL{$b} <=> $SORT_VAL{$a}} keys %SORT_VAL);
		#dp::dp "------------" . scalar(@$sorted_keysp) . "/" . keys(%SORT_VAL) . "\n";

		foreach my $k (@$sorted_keysp){
			my $csv = $csvp->{$k};
			#dp::dp "$k($dt_start, $dt_end)\t". join(",", @$csv[$dt_start..$dt_end]) . "  " . $SORT_VAL{$k} . "\n";;
		}
	}

##	foreach my $k (@$sorted_keysp){
##		dp::dp sprintf("$k : %.2f\n", $SORT_VAL{$k});
##	}
	return (@$sorted_keysp);
}


#
#	Generate Glaph from csv file by gnuplot
#
sub	graph
{
	my $self = shift;
	my($csv_for_plot, $gdp, $gp) = @_;

	my $start_date = $gp->{start_date} // "-NONE-";
	my $end_date = $gp->{end_date} // "-NONE-";

	#dp::dp "START_DATE: $start_date END_DATE: $end_date\n";

	my $src_info = $self->{src_info} // "";
	if($src_info){
		$src_info = "[$src_info]";
	}
	my $dsc = $gp->{dsc} // "";
	$dsc =~ s/~//;
	my $title = join(" ", $dsc, ($gp->{static}//""), "($end_date)") . "    $src_info";
	$title =~ s/_/\\_/g;	# avoid error at plot
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
	my $term_x_size = $gp->{term_x_size} // $gdp->{term_x_size};
	my $term_y_size = $gp->{term_y_size} // $gdp->{term_y_size};


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


	#
	#	Gen Plot Param
	#
	my @p= ();
	my $pn = 0;

	#dp::dp "$csvf\n";
	open(CSV, $csvf) || die "cannot open $csvf";
	binmode(CSV, ":utf8");
	my $l = <CSV>;
	$l =~ s/[\r\n]+$//;
	close(CSV);

	my @label = split(/$dlm/, $l);
	dp::dp "CSV: $csvf\n";
	dp::dp "PLOT $plotf\n";
	#dp::dp "### $csvf\n";

	#my $src_csv = $self->{src_csv} // "";
	#my $y2_source = $gp->{y2_source} // ($gdp->{y2_source} // "");
	my $y2key = $gp->{y2key} // "";
	#dp::dp "soruce_csv[$src_csv] $y2_source\n";
	#$src_csv = "" if($y2_source eq "");
	
	#
	#	Set yrange
	#
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

CSV_FILE = '#CSV_FILE#'

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
	for(my $i = 1; $i <= $#label; $i++){
		my $graph = $gp->{graph} // ($gdp->{graph} // $DEFAULT_GRAPH);
		my $y2_graph = "";
		my ($key, $axis_flag, $graph_def) = split($LABEL_DLM, $label[$i]);
		if($gp->{label_sub_from}){
			my $sub_from = $gp->{label_sub_from};
			my $sub_to = $gp->{label_sub_to} // "";
			$key =~ s/$sub_from/$sub_to/;
		}
		#dp::dp "[$graph_def]\n";
		if($graph_def =~ /^#D#/){
			if(defined $GRAPH_KIND->{$graph_def}){
				$graph_def = $GRAPH_KIND->{$graph_def} ;
			}
			else {
				dp::WARNING "graph_def may wrong: $graph_def\n";
			}
		}
		#dp::dp "[$key]\n";

		$axis_flag = $axis_flag // "y1";
		#dp::dp join(",", $label[$i], $key, $axis_flag) . "\n";
		$key =~ s/^\d+:// if($gp->{no_label_no} // "");
		$key =~ s/[']/_/g;	# avoid error at plot
		$key =~ s/_/\\_/g;	# avoid error at plot
		#dp::dp "### $i: $key $src_csv, $y2key\n";
		$pn++;

		my $axis =	"axis x1y1";
		my $dot = "";
		#if($y2_source ne "" && $src_csv ne ""){		#####
		if(($y2key ne "" && $y2key && $key =~ /$y2key/) || $axis_flag =~ /y2/) {
			$axis = "axis x1y2" ;
			$dot = "dt (7,3)";
			$graph = $gp->{y2_graph} // ($gdp->{y2_graph} // $DEFAULT_GRAPH);
			#dp::dp "$key $y2key/$axis_flag: [$axis]\n";
		}
		#dp::dp "axis:[$axis]\n";
		#my $pl = sprintf("'%s' using 1:%d $axis with lines title '%d:%s' linewidth %d $dot", 
		#				$csvf, $i + 1, $i, $label[$i], ($pn < 7) ? 2 : 1);

		my $pl = "";
		if($graph_def){
			#dp::dp "[$graph_def]\n";
			if($graph_def =~ /notitle/){
				$pl = sprintf("CSV_FILE using 1:%d $axis with $graph_def ", $i + 1);
			}
			else {
				$pl = sprintf("CSV_FILE using 1:%d $axis with $graph_def title '%s' ", $i + 1, $key);
			}
			#dp::dp "[$graph_def][$pl]\n";
		}
		else {
			if($graph =~ /line/){
				$graph .= sprintf(" linewidth %d $dot ", ($pn < 7) ? 2 : 1);
			}
			elsif($graph =~ /box/){
				#dp::dp "BOX\n";
				$graph =~ s/box/box fill/ if(! ($graph =~ /fill/));
			}
			$pl = sprintf("CSV_FILE using 1:%d $axis with $graph title '%d:%s' ", $i + 1, $i, $key);
		}
		push(@p, $pl);
	}

	#push(@p, "0 with lines dt '-' title 'base line'");
	my $additional_plot = $gp->{additional_plot} // ($gdp->{additional_plot} // "");
    if($additional_plot){
        #dp::dp "additional_plot: " . $additional_plot . "\n";
		push(@p, $additional_plot);
		#my @w = split(/,/, $additional_plot);
		#push(@p, @w);
    }

	$PARAMS =~ s/#CSV_FILE#/$csvf/g;
	#my $plot = join(",", @p);
	my $plot = join(",\\\n", @p);
	$PARAMS =~ s/#PLOT_PARAM#/$plot/g;
	dp::dp $plot . "\n" if($VERBOSE);

	my $date_list = $self->{date_list};
	my $dt_start = $gp->{dt_start};
	my $dt_end = $gp->{dt_end};
#	$dt_start = ($dt_start//"") ? $dt_start : 0;
#	$dt_end = ($dt_end//"") ? $dt_end : &csv_size($csvp);		# 2021.03.15
#	if($dt_start < 0){											# 2021.03.15
#		$dt_start = &csv_size($csvp) + $dt_start;						# 2021.03.15
#	}															# 2021.03.15
#	if($dt_end < 0){											# 2021.03.15
#		$dt_end = &csv_size($csvp) + $dt_end;					# 2021.03.15
#	}															# 2021.03.15
	#my $dt_start = $gp->{dt_start};
	#my $dt_end = $gp->{dt_end};
	#dp::dp join(",", @$date_list) . "\n";
	#dp::dp "###" . join(",", $dt_start, $dt_end, $date_list->[$dt_start], $date_list->[$dt_end], scalar(@$date_list)) . "\n";

	#
	#	Week Line
	#
	my $RELATIVE_DATE = 7;
	my @aw = ();

	my $den = $gp->{dt_end};
	#dp::dp "range: " . join(",", $den, scalar(@$date_list) ) . "\n"; 
	my $last_date = csvlib::ymds2tm($date_list->[$den]) / (24 * 60 * 60);	# Draw arrow on sunday
	my $s_date = ($last_date - 2) % 7;
	$s_date = 7 if($s_date == 0);
	#dp::dp "DATE: " . $DATES[$date] . "  " . "$date -> $s_date -> " . ($date - $s_date) . "\n";

	for(my $dn = $gp->{dt_end} - $s_date; $dn > $gp->{dt_start}; $dn -= $RELATIVE_DATE){
		my $mark_date = $date_list->[$dn];
		next if($mark_date le $start_date || $mark_date ge $end_date);
		
		#dp::dp "ARROW: $dn, [$mark_date]\n";
		my $a = sprintf("set arrow from '%s',Y_MIN to '%s',Y_MAX nohead lw 1 dt (3,7) lc rgb \"dark-red\"",
			$mark_date,  $mark_date);
		push(@aw, $a);
	}
	my $arw = join("\n", @aw);
	#dp::dp "ARROW: $arw\n";
	$PARAMS =~ s/#ARROW#/$arw/;	

	#dp::dp "$plotf\n";
	open(PLOT, ">$plotf") || die "cannto create $plotf";
	binmode(PLOT, ":utf8");
	print PLOT $PARAMS;
	close(PLOT);

	#system("cat $plotf");
	#dp::dp "gnuplot $plotf\n";
	system("gnuplot $plotf");
	#dp::dp "-- Done\n";
}

#
#
#
sub	check_download
{
	my $self = shift;

	my $flag_file = "$config::CSV_PATH/" . $self->{id} . ".flag";

	dp::dp "DOWNLOAD  $flag_file\n";
	my $download = 1;
	if(-f $flag_file){
		my $now = time;
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($flag_file);	
		my $elpt = $now - $mtime;
		#dp::dp "$now $mtime $elpt " .sprintf("%.2f", $elpt / (60 * 60)) . "\n";
		if($elpt < (2 * 60 * 60 )){
			$download = 0;
		}
	}
	#dp::dp "Donwload: $download\n";
	if($download){
		system("touch $flag_file");
	}
	return $download;
}

1;
