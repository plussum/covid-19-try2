#!/usr/bin/perl
#
#	Tokyo Open Data CSV version
#
# 
# 東京都 新型コロナウイルス感染症検査の陽性率・検査人数
# URL: https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_positivity_rate_in_testing.csv
#	全国地方公共団体コード	都道府県名	市区町村名	判明_年月日	PCR検査陽性者数	抗原検査陽性者数	PCR検査陰性者数	抗原検査陰性者数	検査人数(7日間移動平均)	陽性率
# 東京都 新型コロナウイルス感染症入院患者数
# URL: https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_details_testing_positive_cases.csv
#	全国地方公共団体コード	都道府県名	市区町村名	日付	陽性者数（累計）	入院中	軽症・中等症	重症	宿泊療養	自宅療養	調整中	死亡	退院

#
# 東京都_新型コロナウイルス陽性患者発表詳細
# URL: https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_patients.csv
# 東京都_新型コロナウイルス陽性患者発表詳細
# URL: https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_patients.csv
# 東京都 新型コロナウイルス感染症重症患者数
# URL: https://stopcovid19.metro.tokyo.lg.jp/data/130001_tokyo_covid19_details_testing_positive_cases.csv
#
#
#
package deftkocsv;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(deftkocsv);

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
my $TKOCSV_DL_FLAG_FILE = "$CSV_PATH/tkocsv_flag";


####################################################################
#
#	https://github.com/kaz-ogiwara/covid19
#
# year,month,date,prefectureNameJ,prefectureNameE,testedPositive,peopleTested,hospitalized,serious,discharged,deaths,effectiveReproductionNumber
# 	2020,2,8,東京,Tokyo,3,,,,,,
#
#my $TKO_PATH = "$WIN_PATH/tokyokeizai";
#my $BASE_DIR = "$TKO_PATH/covid19/data";
#our $transaction = "$BASE_DIR/prefectures.csv";
my $TKOCSV_CSV = "$CSV_PATH/tkocsv.csv";
our $TKOCSV_DEF = 
{
	id => "tkocsv",
	src_info => "Tokyo  COVID-19 data (CSV)",
	main_url => "https://stopcovid19.metro.tokyo.lg.jp/",
	src_file => $TKOCSV_CSV,
	src_url => 	"--- src url ---",		# set
	down_load => \&download,

	direct => "holizontal",		# vertical or holizontal(Default)
	cumrative => 0,
	timefmt => '%Y-%m-%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => ["item"],		# PrefectureNameJ, and Column name
	data_start => 1,
	alias => {},
};
our $TKOCSV_GRAPH = {
	html_title => $TKOCSV_DEF->{src_info},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/tkocsv_open_data.html",

	dst_dlm => "\t",
	avr_date => 7,
	END_OF_DATA => $END_OF_DATA,
	graph => "line",

	timefmt => '%Y-%m-%d', format_x => '%m/%d',
	term_x_size => 1000, term_y_size => 350,

	ylabel => "Number", ymin => 0,
	additional_plot => "",

	graph_params => [
	],
};

sub	download
{
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

	my $csv = {};
	my @date = ();
	my $file_no = 0;
	my $col_no = 0;
	my @header = ();
	my $download = 1;

	dp::dp "DOWNLOAD  $TKOCSV_DL_FLAG_FILE\n";
	if(-f $TKOCSV_DL_FLAG_FILE){
		my $now = time;
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($TKOCSV_DL_FLAG_FILE);	
		my $elpt = $now - $mtime;
		dp::dp "$now $mtime $elpt " .sprintf("%.2f", $elpt / (60 * 60)) . "\n";
		if($elpt < (2 * 60 * 60 )){
			$download = 0;
		}
	}
	dp::dp "Donwload: $download\n";
	if($download){
		system("touch $TKOCSV_DL_FLAG_FILE");
	}
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
		dp::dp "### COL_NO: $col_no\n";
		$col_no += $#vlist;
		$file_no++;
	}
	
	#
	#	Gen csv file from sources
	#
	open(OUT, "> $TKOCSV_CSV") || die "cannot create $TKOCSV_CSV";
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
		dp::dp $header[$i] . "\n";
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
