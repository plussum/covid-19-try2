#!/usr/bin/perl
#
#
#
package defmhlw;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(defmhlw);

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
my $MLW_DL_FLAG_FILE = "$CSV_PATH/mhlw_flag";


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
my $MHLW_CSV = "$CSV_PATH/mhlw.csv";
our $MHLW_DEF = 
{
	id => "mhlw",
	src_info => "Japan COVID-19 data (MHLW)",
	main_url => "-- Kosei Roudousyou --- ",
	src_file => $MHLW_CSV,
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
our $MHLW_GRAPH = {
	html_title => $MHLW_DEF->{src_info},
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/mhlw_open_data.html",

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
	my $urls = [		# for keep order of records
		{pcr_positive => "https://www.mhlw.go.jp/content/pcr_positive_daily.csv"},
		{pcr_tested_people => "https://www.mhlw.go.jp/content/pcr_tested_daily.csv"},
		{cases => "https://www.mhlw.go.jp/content/cases_total.csv"},
		{recovery => "https://www.mhlw.go.jp/content/recovery_total.csv"},
		{deaths => "https://www.mhlw.go.jp/content/death_total.csv"},
	#	{pcr_tested_cases => "https://www.mhlw.go.jp/content/pcr_case_daily.csv"},
	];

	my $csv = {};
	my @date = ();
	my $file_no = 0;
	my $col_no = 0;
	my @header = ();
	my $download = 1;

	dp::dp "DOWNLOAD  $MLW_DL_FLAG_FILE\n";
	if(-f $MLW_DL_FLAG_FILE){
		my $now = time;
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($MLW_DL_FLAG_FILE);	
		my $elpt = $now - $mtime;
		dp::dp "$now $mtime $elpt " .sprintf("%.2f", $elpt / (60 * 60)) . "\n";
		if($elpt < (2 * 60 * 60 )){
			$download = 0;
		}
	}
	dp::dp "Donwload: $download\n";
	if($download){
		system("touch $MLW_DL_FLAG_FILE");
	}
	foreach my $items (@$urls){
		foreach my $item (keys %$items){
			my $csvf = "$CSV_PATH/mhlw_" . "$item.csv";
			my $csvf_txt = "$csvf.txt";
			my $cmd = "wget " . $items->{$item} . " -O $csvf";
			&do($cmd) if($download);
			&do("nkf -w80 $csvf > $csvf_txt");

			dp::dp $csvf . "\n";
			open(FD, "$csvf") || die "canot open $csvf.txt";
			binmode(FD, ":utf8");
			my @data = ();
			my $rn = 0;
			my $vn = 0;
			for($rn = 0; <FD>; $rn++){
				#print;
				s/[\r\n]+$//;;
				my ($dt, @vals) = split(/,/, $_);
				if($rn <= 0){
					s/^[^,]+,//;
					push(@header, $item);
					next;
				}
				my ($y, $m, $d) = split(/\//, $dt);
				$dt = sprintf("%04d-%02d-%02d", $y, $m, $d);
				$csv->{$dt} = [] if(! defined $csv->{$dt});
				$vn = $#vals if($#vals > $vn);
				if($file_no == 0){
					#dp::dp "[$dt]\n";
					push(@date, $dt);
				}
				#dp::dp "[$dt] $vn $_\n";
				#dp::dp $#vals . "\n";
				for(my $i = 0; $i <= $#vals; $i++){
					my $n = $col_no + $i;
					$csv->{$dt}->[$n] = $vals[$i];
				}
			}
			close(FD);
			$col_no += $vn + 1;
			$file_no++;
		}
	}
	open(OUT, "> $MHLW_CSV") || die "cannot create $MHLW_CSV";
	binmode(OUT, ":utf8");
	my @date_list = (sort keys %$csv);
	print OUT join(",", "item", @date_list) . "\n";
	for(my $i = 0; $i <= $#header; $i++){
		my @data = ();
		foreach my $dt (@date_list){
			push(@data, sprintf("%.2f", $csv->{$dt}->[$i] // 0));
		}
		if($header[$i] eq "deaths"){
			for(my $i = $#date_list; $i > 0; $i--){
				$data[$i] = $data[$i] - $data[$i-1];
			}
		} 
		print OUT join(",", $header[$i], @data) . "\n";
	}
			
	#print OUT join(",", @header) . "\n";
	#foreach my $dt (sort keys %$csv){
	#	my  @data = ();
	#	for(my $i = 0; $i < $col_no; $i++){
	#		push(@data, $csv->{$dt}->[$i] // 0);
	#	}
	#	print OUT join(",", $dt, @data) . "\n";
	#	#dp::dp join(",", $date[$dt]) . "\n";
	#}
	close(OUT);
}

sub	do
{
	my ($cmd) = @_;

	dp::dp $cmd . "\n";
	system($cmd);
}

1;
