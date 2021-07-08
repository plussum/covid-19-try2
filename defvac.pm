#!/usr/bin/perl
#
#	Tokyo Open Data CSV version
#
# 
# https://vrs-data.cio.go.jp/vaccination/opendata/latest/prefecture.ndjson
# {"date":"2021-04-12","prefecture":"01","gender":"F","age":"-64","medical_worker":false,"status":1,"count":113}
# {"date":"2021-04-12","prefecture":"01","gender":"F","age":"65-","medical_worker":false,"status":1,"count":88}
# {"date":"2021-04-12","prefecture":"01","gender":"M","age":"-64","medical_worker":false,"status":1,"count":38}
# {"date":"2021-04-12","prefecture":"01","gender":"M","age":"65-","medical_worker":false,"status":1,"count":26}
# {"date":"2021-04-12","prefecture":"01","gender":"U","age":"-64","medical_worker":false,"status":1,"count":12}
# {"date":"2021-04-12","prefecture":"01","gender":"U","age":"UNK","medical_worker":false,"status":1,"count":1}
#
package defvac;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(defvac);

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
my $VACCINE_DL_FLAG_FILE = "$CSV_PATH/vaccine_flag";

my $AREA_CODE = {};


####################################################################
#
# https://vrs-data.cio.go.jp/vaccination/opendata/latest/prefecture.ndjson
# {"date":"2021-04-12","prefecture":"01","gender":"F","age":"-64","medical_worker":false,"status":1,"count":113}
#
my $VACCINE_CSV = "$CSV_PATH/vaccine.csv";
my $VACCINE_JSON = "$CSV_PATH/vaccine.ndjson";
my $VACCINE_URL = "https://vrs-data.cio.go.jp/vaccination/opendata/latest/prefecture.ndjson"; 
our $VACCINE_DEF =
{
	id => "vaccine",
	src_info => "CISO Dashboad, Tokyo Open Data",
	main_url => "https://cio.go.jp/c19vaccine_dashboard",
	src_file => $VACCINE_CSV,
	src_url => $VACCINE_URL,
	down_load => \&download,

	direct => "holizontal",		# vertical or holizontal(Default)
	cumrative => 0,
	timefmt => '%Y-%m-%d',		# comverbt to %Y-%m-%d
	src_dlm => ",",
	key_dlm => "#",
	keys => [0,1,2,3],		# PrefectureNameJ, and Column name
	data_start => 4,
	alias => {},
};
our $VACCINE_GRAPH = {
	html_title => ($VACCINE_DEF->{src_info}),
	png_path   => "$PNG_PATH",
	png_rel_path => $PNG_REL_PATH,
	html_file => "$HTML_PATH/vaccine.html",

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
	my $csv = {};
	my @date = ();
	my $file_no = 0;
	my $col_no = 0;
	my @header = ();
	my $download = 1;
	# {"date":"2021-04-12","prefecture":"01","gender":"F","age":"-64","medical_worker":false,"status":1,"count":113}
	my @item_names = ("prefecture", "age","status");

	my %POP = ();
	csvlib::cnt_pop(\%POP);	

	&load_area_code();
	dp::dp "DOWNLOAD  $VACCINE_DL_FLAG_FILE\n";
	if(-f $VACCINE_DL_FLAG_FILE){
		my $now = time;
		my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($VACCINE_DL_FLAG_FILE);	
		my $elpt = $now - $mtime;
		#dp::dp "$now $mtime $elpt " .sprintf("%.2f", $elpt / (60 * 60)) . "\n";
		if($elpt < (2 * 60 * 60 )){
			$download = 0;
		}
	}
	#dp::dp "Donwload: $download\n";
	if($download){
		system("touch $VACCINE_DL_FLAG_FILE");
	}

	my $csvf = $VACCINE_JSON;
	my $cmd = "wget $VACCINE_URL -O $csvf.gz; gunzip -f $csvf.gz";
	if($download || ! (-f $csvf)){
		unlink($csvf);
		&do($cmd) ;
	}

	dp::dp $csvf . "\n";
	my %ages = ("65-" => "ge65", "-64" => "le64", "UNK" => "UNK", "all" => "all");

	open(FD, "$csvf") || die "canot open $csvf";
	binmode(FD, ":utf8");
	my %date_list_flag = ();
	my $data_hash = {};
	while(<FD>){
		#dp::dp $_;
		s/[\r\n]+$//;;
		my $record = &perse_json($_);
		my $date = $record->{date}//"--undef--";
		my $pref = $record->{prefecture}//"--undef--";
		my $age = $record->{age}//"--undef--";
		$age = $ages{$age};
		my $status = $record->{status}//"--undef--";
		my $medical = $record->{medical_worker}//"--undef--";
	
		my $v = $record->{count};
		if($v =~ /\D/){
			dp::dp "[$v]\n";
			exit;
		}
		$data_hash->{$date}->{$pref}->{$age}->{$status} += $record->{count};
		$data_hash->{$date}->{$pref}->{$age}->{any} += $record->{count};
		$data_hash->{$date}->{$pref}->{all}->{$status} += $record->{count};
		$data_hash->{$date}->{$pref}->{all}->{any} += $record->{count};
		$date_list_flag{$date} ++;
	}
	close(FD);

	#dp::dp "### COL_NO: $col_no\n";
	
	#
	#	Gen csv file from sources
	#
	open(OUT, "> $VACCINE_CSV") || die "cannot create $VACCINE_CSV";
	binmode(OUT, ":utf8");

	my @date_list = (sort keys %date_list_flag);
	print OUT join(",", @item_names, @date_list) . "\n";
	foreach my $pref (1..47){
		$pref = sprintf("%02d", $pref);
		my $pref_name = $AREA_CODE->{$pref};
		dp::dp "[$pref]\n" if(! $pref_name);
		#dp::dp "[$pref:$pref_name]\n";
		if(!defined $POP{$pref_name}){
			dp::ABORT "POP: [$pref_name]\n";
		}
		my $pop = $POP{$pref_name} / 100;
		#foreach my $age ("65-", "-64", "UNK", "all"){
		foreach my $age ("ge65", "le64", "UNK", "all"){
			foreach my $status (1, 2, "any"){
				my @vals = ();
				my @cvals = ();
				my @pvals = ();
				my $lv = 0;
				my $cs = "$status" . "-c";
				my $ps = "$status" . "-cp";
				foreach my $date (@date_list){
					my $v = $data_hash->{$date}->{$pref}->{$age}->{$status};
					$v = 0 if(!$v || $v < 0);
					push(@vals, $v);
					push(@cvals, $v + $lv);
					push(@pvals, sprintf("%.3f", ($v + $lv) / $pop));
					$lv = $v + $lv;
				}
				print OUT join(",", $pref_name, $age, $status, @vals) . "\n";
				print OUT join(",", $pref_name, $age, $cs, @cvals) . "\n";
				print OUT join(",", $pref_name, $age, $ps, @pvals) . "\n";
				#if($pref_name =~ /東京/){
				#	print join(",", $pref_name, $age, $ps, @pvals) . "\n";
				#}
			}
		}
	}
	close(OUT);
}

# {"date":"2021-04-12","prefecture":"01","gender":"F","age":"-64","medical_worker":false,"status":1,"count":113}
sub	perse_json
{
	my ($line) = @_;
	$line =~ s/\{(.*)\}/$1/;
	my @items = split(/,/, $line);
	
	my $record = {};
	my @w = ();
	foreach my $item (@items){
		$item =~ /\"([^:\"]+)\":\"*([^\"]+)"*$/;
		my ($name, $val) = ($1, $2);
		$record->{$name} = $val;
		push(@w, $name . ":" . $val);
	}
	#dp::dp join(",", @w) . "\n";
	return $record;
}

sub	do
{
	my ($cmd) = @_;

	dp::dp $cmd . "\n";
	system($cmd);
}

sub	load_area_code
{
	my $area_code_file = join("/", $config::WIN_PATH, "areacode.csv");
	dp::dp $area_code_file . "\n";

	open(FD, $area_code_file) || die "cannot open $area_code_file";
	binmode(FD, ":utf8");
	while(<FD>){
		s/[\r\n]+$//;
		next if(!/^\d/);

		my($code, @w) = split(/,/, $_);
		my $area = join("-", $w[0], $w[1]);
		$AREA_CODE->{$code} = $area;
		if($code =~ /^(\d\d)0/){
			my $pcode = $1;
			$AREA_CODE->{$pcode} = $w[0];
			#dp::dp "$pcode:$w[0]\n";
		}
	}
	close(FD);
}

1;
