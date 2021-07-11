#
#	owid: Our World in Data
#		https://ourworldindata.org/covid-vaccinations
#		https://github.com/owid/covid-19-data
# location,iso_code,date,total_vaccinations,people_vaccinated,people_fully_vaccinated,
#	daily_vaccinations_raw,daily_vaccinations,total_va,
#	ccinations_per_hundred,people_vaccinated_per_hundred,people_fully_vaccinated_per_hundred,daily_vaccinations_per_million
#
#	Afghanistan,AFG,2021-02-22,0,0,,,,0.0,0.0,,
#	Afghanistan,AFG,2021-02-23,,,,,1367,,,,35
#
#
package defowid;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(owid);

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


####################################################################
#
my $OWID_ROOT = "$WIN_PATH/owid/covid-19-data";
my $OWID_VAC_CSV = "$OWID_ROOT/public/data/vaccinations/vaccinations.csv";

our $OWID_VAC_DEF = 
{
	id => "owidvac",
	src_info => "OWID Vaccine", 
	main_url => "https://ourworldindata.org/covid-vaccinations",
	src_file => $OWID_VAC_CSV,
	src_url => 	"https://github.com/owid/covid-19-data",	# github 
	down_load => \&download,

	direct => "vertical_multi",		# vertical or holizontal(Default)
	cumrative => 0,
	timefmt => '%Y-%m-%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["location","item_name"],		# Japan, total_vaccinations_per_hundred,
	date_col => 2,
	data_start => 3,
	item_name_line => 1,		# from 1
	data_start_line => 2,		# from 1 
	alias => {},
	load_col => [
 		"total_vaccinations_per_hundred", "people_vaccinated_per_hundred","people_fully_vaccinated_per_hundred",
	],
};

our $OWID_VAC_GRAPH = {
	html_title => $OWID_VAC_DEF->{src_info},
	png_path   => $PNG_PATH,
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/tkow.html",

	dst_dlm => "\t",
	avr_date => 7,
	graph => "line",

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	#y2label => 'ERN', y2min => 0, y2max => 3, y2_source => 0,		# soruce csv definition for y2
	ylabel => "Number", ymin => 0,
	additional_plot => "",

	graph_params => [
	],
};

#csv2graph::new($TKW_DEF); 							# Load Johns Hopkings University CCSE
#csv2graph::load_csv($TKW_DEF);

#csv2graph::gen_html($TKW_DEF, $TKW_GRAPH, $TKW_GRAPH->{graph_params}); 

#
#	Down Load CSV 
#
sub	download
{
	my $self = shift;
	dp::dp "[$self] " . join(",", @_) . "\n";
	if($self->check_download()){
		system("(cd $OWID_ROOT; git pull origin master)");
	}
	return 1;
}

1;
