#!/usr/bin/perl
#
#	Tokyo Open Data CSV version
#
#"datetime","Temperature","Humidity","CO2","PM1_0","PM2_5","PM4_0","PM10_0","TVOC","Barometric","UVIndex"
#"2021-09-07T00:00:28+09:00",26.1,55.6,417,3.5,3.7,3.7,3.7,557,1012,0.23
#"2021-09-07T00:01:28+09:00",26.1,55.6,417,3.6,3.8,3.8,3.8,539,1012,0.08
#"2021-09-07T00:02:28+09:00",26.2,55.5,415,3.7,3.9,3.9,3.9,532,1012,0.21
#
#
package defratoc;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(ratoc);

use strict;
use warnings;
use utf8;
use Encode 'decode';

my $WIN_PATH = "/mnt/f/_share/netatmo/RATOC/";
my $HTML_PATH = "$WIN_PATH/HTML";
my $PNG_PATH  = "$WIN_PATH/PNG";
my $PNG_REL_PATH  = "../PNG";
my $CSV_PATH  = "$WIN_PATH/CSV";


my $RATOC_CSV = "$CSV_PATH/ratoc.csv";
our $CDP_DEF = 
{
	id => "rtoc",
	src_info => "RTOC AIR ",
	main_url => "-- main URL --",
	src_file => $RATOC_CSV,
	src_url => 	"--- src url ---",		# set
	down_load => \&download,

	direct => "vertical",		# vertical or holizontal(Default)
	cumrative => 0,
	#"2021-09-07T00:00:28+09:00",26.1,55.6,417,3.5,3.7,3.7,3.7,557,1012,0.23
	timefmt => '%Y-%m-%dT%H:%M:%STZ',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["item"],		# PrefectureNameJ, and Column name
	data_start => 1,
	item_name_line => 0,
	data_start_line => 1,

	alias => {},
};
our $TKOCSV_GRAPH = {
	html_title => $CDP_DEF->{src_info},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/ratoc01.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => "###EOD###",
	graph => "line",

	timefmt => '%Y-%m-%d %H:%M:%S', format_x => '%m/%d %H:%M',
	term_x_size => 1000, term_y_size => 350,

	ylabel => "Number", ymin => 0,
	additional_plot => "",

	graph_params => [
	],
};

# 東京都 新型コロナウイルス感染症検査の陽性率・検査人数
#	全国地方公共団体コード	都道府県名	市区町村名	判明_年月日	PCR検査陽性者数	抗原検査陽性者数	PCR検査陰性者数	抗原検査陰性者数	検査人数(7日間移動平均)	陽性率
# 東京都 新型コロナウイルス感染症入院患者数
# URL: https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_details_testing_positive_cases.csv
#	全国地方公共団体コード	都道府県名	市区町村名	日付	陽性者数（累計）	入院中	軽症・中等症	重症	宿泊療養	自宅療養	調整中	死亡	退院
my $urls = [		# for keep order of records
	{name => "pcr_tested", values => [3,4,5,6,7,8,9],
		item_names => ["date", "pcr_positive", "antigen_positive", "pcr_negative", "antigen_negative", "inspected", "positive_rate"],
		url => "https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_positivity_rate_in_testing.csv", },
	{name => "pcr_hospitalized", values =>[3,4,5,6,7,8,9,10,11,12,13],
		item_names => ["date", "positive_number", "hospitalized", "mid-modelate", "severe", "residential", "home","adjusting", "deaths", "discharged"],
		url => "https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_details_testing_positive_cases.csv", },
];

sub	download
{
	my $self = shift;
	my ($p) = @_;
	$p = $p // {};
	my $download = $self->check_download();
	$download = 1 if(($p->{download}//0) > 1);
	#csvlib::disp_caller(1..3);
	#dp::dp "[$self]\n";
	my $csv = {};
	my @date = ();
	my $file_no = 0;
	my $col_no = 0;
	my @header = ();

	foreach my $items (@$urls){
		my $csvf = "$CSV_PATH/tkocsv_" . $items->{name} . ".csv";
		my $csvf_txt = "$csvf.txt";
		my $cmd = "wget " . $items->{url} . " -O $csvf";
		if($download || ! (-f $csvf)){
			&do($cmd) ;
		}
		&do("nkf -w80 $csvf > $csvf_txt");

		dp::dp $csvf . "\n";
		open(FD, "$csvf") || die "canot open $csvf.txt";
		binmode(FD, ":utf8");
		my @data = ();
		my $rn = 0;
		my $vn = 0;

		<FD>;
		my @item_names = @{$items->{item_names}};
		my @vlist = @{$items->{values}};
		#s/^[^,]+,//;
		#push(@header, $items->{name});
		for(my $i = 1; $i <= $#item_names; $i++){
			push(@header, $item_names[$i]);
		}

		while(<FD>){
			#print;
			s/[\r\n]+$//;;
			my @w = split(/,/, $_);

			my @vals = ();
			for(my $i = 0; $i <= $#vlist; $i++){		# #0 = date
				my $vn = $vlist[$i];
				push(@vals, $w[$vn]//0);
			}
			my $dt = shift(@vals);
			$csv->{$dt} = [] if(! defined $csv->{$dt});
			if($file_no == 0){
				#dp::dp "[$dt]\n";
				push(@date, $dt);
			}
			for(my $i = 0; $i <= $#vals; $i++){
				my $n = $col_no + $i;
				$csv->{$dt}->[$n] = $vals[$i];
			}
		}
		close(FD);
		#dp::dp "### COL_NO: $col_no\n";
		$col_no += $#vlist;
		$file_no++;
	}
	
	#
	#	Gen csv file from sources
	#
	open(OUT, "> $RATOC_CSV") || die "cannot create $RATOC_CSV";
	binmode(OUT, ":utf8");
	my @date_list = (sort keys %$csv);
	print OUT join(",", "item", @date_list) . "\n";
	for(my $i = 0; $i <= $#header; $i++){
		my @data = ();
		foreach my $dt (@date_list){
			my $v = $csv->{$dt}->[$i] // 0;
			$v = 0 if(! $v);
			push(@data, sprintf("%.2f", $v));
		}
		if($header[$i] eq "deaths"){
			for(my $i = $#date_list; $i > 0; $i--){
				$data[$i] = $data[$i] - $data[$i-1];
			}
		} 
		#dp::dp join(",", $header[$i], @data) . "\n";
		#dp::dp $header[$i] . "\n";
		print OUT join(",", $header[$i], @data) . "\n";
	}
	close(OUT);
}

sub	do
{
	my ($cmd) = @_;

	dp::dp $cmd . "\n";
	system($cmd);
}

1;
