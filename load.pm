#
#
#
package load;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(load);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use JSON qw/encode_json decode_json/;
use Data::Dumper;
use config;
use csvlib;
use dump;
use util;

my $VERBOSE = 0;

my $FIRST_DATE = "";
my $LAST_DATE = "";

#
#	Lpad CSV File
#
sub	load_csv
{
	my $self = shift;
	my ($p) = @_;

	my $download = $p->{download} // "";
	my $src_file = "";
	$src_file = ($p->{src_file} // ($self->{src_file} // "")) if($p);
	#dp::dp "#### " . $self->{src_file} . "\n";
	
	if(($download // "")){
		my $download = $self->{download};
		$download->($self);
	}
	if(! $src_file){
		dp::WARNING "load_csv: no src_file information\n";
		return "";
	}
	if(! -e $src_file){
		dp::WARNING "load_csv: $src_file is not found\n";
		return "";
	}
	
	#
	#
	#
	dp::dp "LOAD CSV  [$self->{src_info}][$self->{id}]\n";
	my $rc = 0;
	my $direct = $self->{direct} // "";
	if($direct =~ /json/i){
		$rc = &load_json($self, $src_file);
	}
	elsif($direct =~ /transact/i){
		$rc = &load_transaction($self, $src_file);
	}
	elsif($direct =~ /vertical/i){
		$rc = load_csv_vertical($self, $src_file);
	}
	else {
		$rc = load_csv_holizontal($self, $src_file);
	}

	if(($self->{cumrative} // "")){
		&cumrative2daily($self);
	}

	#
	#	src_csv: use for marge 
	#
	#dp::dp "----- $self->{src_csv}\n";
	if(! defined $self->{src_csv}){
		$self->{src_csv} = {};
	}
	my $src_csv = $self->{src_csv}; 
	my $csvp = $self->{csv_data};
	foreach my $key (keys %{$self->{csv_data}}){
		#dp::dp "$key => $csvp->{$key}  " . ($src_csv->{$key} // "undef") . "\n";
		$src_csv->{$key} = 0;
		
	}
	#dp::dp "-----\n";
	#@{$self->{item_name_list}} = @w[0..($data_start-1)];	# set item_name 


	#
	#	set alias
	#
	$self->set_alias($self->{alias});

	#
	#	DEBUG: Dump data 
	#
	my $dates = $self->{dates};
	my $date_list = $self->{date_list};
	#dp::dp "loaded($self->{id}) $dates records $date_list->[0] - $date_list->[$dates] ($rc)\n";
	$self->dump({ok => 1, lines => 5}) if($rc || $VERBOSE > 1);
	return 0;
}


#
#	load holizontal csv file
#
#			01/01, 01/02, 01/03 ...
#	key1
#	key1
#
sub	load_csv_holizontal
{
	my $self = shift;
	my ($src_file) = @_;

	my $data_start = $self->{data_start};
	my $src_dlm = $self->{src_dlm};
	my $date_list = $self->{date_list};
	my $csv_data = $self->{csv_data};	# Data of record ->{$key}->[]
	my $key_items = $self->{key_items};	# keys of record ->{$key}->[]
	my @keys = @{$self->{keys}};			# Item No for gen HASH Key
	my $timefmt = $self->{timefmt};

	#
	#	Load CSV DATA
	#
	dp::dp "source_file: $src_file\n";
	system("nkf -w80 $src_file >$src_file.utf8");			# -w8 (with BOM) contain code ,,,so lead some trouble
	open(FD, "$src_file.utf8") || die "Cannot open $src_file.utf8";
	binmode(FD, ":utf8");
	my $line = <FD>;
	$line =~ s/[\r\n]+$//;
	#$line =~ s/^.//;				# 2021.02.14 ... amt 
	#$line = decode('utf-8', $line);

	#dp::dp "[" . ord($line) . ":" . substr($line, 0, 20) . "]\n";
	my @item_name = split(/$src_dlm/, $line);

	#dp::dp "[" . join(",", @w[0..5]) . "]\n";

##	my $item_name_list = $self->{item_name_list};
##	my $item_name_hash = $self->{item_name_hash};						# List and Hash need to make here
##	@$item_name_list = @w[0..($data_start - 1)];	# set item_name 
##	for(my $i = 0; $i < scalar(@$item_name_list); $i++){				# use for loading and gen keys
##		my $kn = $item_name_list->[$i];
##		$item_name_hash->{$kn} = $i;
##	}
	$self->add_key_items([$config::MAIN_KEY, @item_name[0..($data_start - 1)]]);

	@$date_list = @item_name[$data_start..$#item_name];
	for(my $i = 0; $i < scalar(@$date_list); $i++){
		$date_list->[$i] = util::timefmt($timefmt, $date_list->[$i]);
	}
		
	$self->{dates} = scalar(@$date_list) - 1;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$#item_name - $data_start];

	#dp::dp join(",", "# ", @$date_list) . "\n";
	dp::dp "keys : ", join(",", @keys). "\n";
	my @key_order = $self->gen_key_order($self->{keys});		# keys to gen record key
	my $load_order = $self->{load_order};
	my $key_dlm = $self->{key_dlm}; 
	my $ln = 0;
	while(<FD>){
		s/[\r\n]+$//;
		#my $line = decode('utf-8', $_);
		my $line = $_;
		my @items = (split(/$src_dlm/, $line));
		my $master_key = select::gen_record_key($key_dlm, \@key_order, ["masterkey", @items]);
		#dp::dp "MASTER_KEY: " .$master_key . "\n";

##		$csv_data->{$k}= [@items[$data_start..$#items]];	# set csv data
##		$key_items->{$k} = [@items[0..($data_start - 1)]];	# set csv data
##		push(@$load_order, $k);

		$self->add_record($master_key, 
				[$master_key, @items[0..($data_start-1)]], [@items[$data_start..$#items]]);		# add record without data
		
		$ln++;
		#last if($ln > 50);
	}
	close(FD);
	#dp::dp "CSV_HOLIZONTASL: " . join(",", @{$self->{item_name_list}}) . "\n";
	return 0;
}


#
#	Load vetical csv file
#
#			key1,key2,key3
#	01/01
#	01/02
#	01/03
#
#	"key" 01/01, 01/02, 01/03
#	key1, 1,2,3
#	key2, 11,12,13
#	key3, 21,22,23
#
sub	load_csv_vertical
{
	my $self = shift;
	my ($src_file) = @_;

	my $remove_head = 1;
	my $data_start = $self->{data_start};
	my $src_dlm = $self->{src_dlm};
	my $date_list = $self->{date_list};
	my $csv_data = $self->{csv_data};
	my $key_items = $self->{key_items};
	my @keys = @{$self->{keys}};
	my $timefmt = $self->{timefmt};
	my $item_name_line = $self->{item_name_line} // 0;
	my $data_start_line = $self->{data_start_line} // 1;
	my $load_col = $self->{load_col} // "";
	my $load_order = $self->{load_order};

	#
	#	set main key (item name) 
	#	vertical csv had only main key (1 key)
	#
	##my $key_name = $self->{key_name} // "";			# set key name as "key" or $self->{key_name}
	##$key_name = $config::MAIN_KEY if(! $key_name);
	$self->add_key_items([$config::MAIN_KEY]);
	#@{$self->{item_name_list}} = ($key_name);		# set item_name 
	#$self->{item_name_hash}->{$key_name} = 0;

	#
	#	Load CSV DATA
	#
	dp::dp "LOAD:$src_file\n";
	system("nkf -w80 $src_file >$src_file.utf8");
	open(FD, "$src_file.utf8" ) || die "Cannot open $src_file.utf8";
	binmode(FD, ":utf8");
	#binmode(FD, ":encording(cp932)");

	#
	#	load item names
	#
	my $ln = 0;
	my $line = "";
	for(; $ln <= $item_name_line; $ln++){
		$line = <FD>;
	}
	$line =~ s/[\r\n]+$//;
	#$line = decode('utf-8', $line);

	#dp::dp "$line\n";

	my @item_names = split(/$src_dlm/, $line);
	if($#item_names <= 1){
		dp::WARNING "may be wrong delimitter [$src_dlm]\n\n";
	}
	shift(@item_names);
	my @load_flag = ();
	for(my $i = 0; $i < $#item_names; $i++){
		$load_flag[$i] = "";
	}
	foreach my $i (@$load_col){
		$load_flag[$i] = 1;
	}

	for(my $cl = 0; $cl <= $#item_names; $cl++){
		next if(! $load_flag[$cl]);

		my $k = $item_names[$cl];
		#$k =~ s/^[0-9]+:// if($remove_head);			# 
		if(defined $key_items->{$k}){					# comvert same item name to unique
			my $kk = "";
			for(my $i = 1; $i < 10; $i++){
				$kk = sprintf("$k%02d", $i);
				last if(!defined $key_items->{$kk});
			}
			if(! $kk){
				dp::WARNING "something wrong,,, [$k] " . join(",", @item_names) . "\n";
				$kk = $k;
			}
			$k = $kk;
			$item_names[$cl] = $kk;
		}
		#dp::dp "$cl: $k\n";
		$self->add_record($k, [$item_names[$cl]], []);		# add record without data
	}

	#
	#	Skip non data row
	#
	for($ln++; $ln < $data_start_line; $ln++){		# skip lines until data_start_line
		$line = <FD>;
	}

	#
	#	Load dated data
	#
	my $added_key = select::added_key($self);

	$ln = 0;
	while(<FD>){
		s/[\r\n]+$//;
		my $line = decode('utf-8', $_);
		my ($date, @items) = split(/$src_dlm/, $line);
	
		#dp::dp "$date, [$src_dlm]" . join(",", @items) ."\n";
		$date_list->[$ln] = util::timefmt($timefmt, $date);
		#dp::dp "date:$ln $date " . $date_list->[$ln] . " ($timefmt) $self->{title}\n";
		#my @w = ($date);	
		for(my $i = 0; $i <= $#items; $i++){
			next if(! $load_flag[$i]);

			my $k = $item_names[$i] . $added_key;
			$csv_data->{$k}->[$ln]= $items[$i];
			#push(@w, "$ln:{". $k . "}:$items[$i]");
		}
		#dp::dp join(",", @w) . "\n";
		$ln++;
	}
	close(FD);

#	foreach my $k (keys %$csv_data){
#		dp::dp "$k: \n" . join(",", @{$csv_data->{$k}}). "\n";
#	}
	$self->{dates} = $ln - 1;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$ln-1];
#	$self->dump({ok => 1, lines => 5});
#	exit;
	return 1;
}

#
#	Load Json format
#
#		Tokyoのように、１次元データ向けに作ってます。２次元データは未実装
#		for examanple, apll prefectures,,,
#
sub	load_json
{
	my $self = shift;
	my ($src_file) = @_;

	my $remove_head = 1;
	my @items = @{$self->{json_items}};
	my $date_key = shift(@items);

	$self->{data_start} = $self->{data_start} // 1 ;
	my $date_list = $self->{date_list};
	my $csv_data = $self->{csv_data};
	my $key_items = $self->{key_items};
	my @keys = @{$self->{keys}};
	my $timefmt = $self->{timefmt};
	my $load_order = $self->{load_order};

	my $rec = 0;
	my $date_name = "";

	dp::dp "$src_file\n";
	#
	#	Read from JSON file
	#
	my $JSON = "";
	open(FD, $src_file) || die "cannot open $src_file";
	while(<FD>){
		$JSON .= $_;
	}
	close(FD);

	my $positive = decode_json($JSON);
	#print Dumper $positive;
	my @data0 = (@{$positive->{data}});
	#dp::dp "### $date_key\n";


	$self->add_key_items([$config::MAIN_KEY, @items]);
	foreach my $master_key (@items){
		$self->add_record($master_key, [$master_key], []);		# add record without data
	}

	my $added_key = select::added_key($self);
	for(my $rn = 0; $rn <= $#data0; $rn++){
		my $datap = $data0[$rn];
		my $date = $datap->{$date_key};
		$date_list->[$rn] = $date;
		for(my $itn = 0; $itn <= $#items; $itn++){
			my $k = $items[$itn] . $added_key;
			my $v = $datap->{$k} // 0;
			$csv_data->{$k}->[$rn] = $v;
			#dp::dp "$k:$itn: $v ($csv_data->{$k})\n" if($rn < 3);
		}
		#dp::dp  join(",", @$dp) . "\n" if($i < 3);
	}
	#print Dumper $date_list;
	#print Dumper $csv_data;
	#foreach my $k (@items){
	#	print Dumper $csv_data->{$k};
	#}
	$self->{dates} = $#data0;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$#data0];
	return 0;
}

#
#	Load Transaction format (One record, One line)
#
sub	load_transaction
{
	my $self = shift;
	my ($src_file) = @_;

	my $data_start = $self->{data_start};
	my $date_list = $self->{date_list};
	my $csv_data = $self->{csv_data};
	my $key_items = $self->{key_items};
	my @keys = @{$self->{keys}};
	my $timefmt = $self->{timefmt};
	my $key_dlm = $self->{key_dlm} // "#";
	my $load_order = $self->{load_order};

	dp::dp "$src_file\n";
	open(FD, $src_file) || die "cannot open $src_file";
	binmode(FD, ":utf8");
	my $line = <FD>;
	$line =~ s/[\r\n]+$//;
	my @items = util::csv($line);

##	my $key_name = $self->{key_name} // "";
##	$key_name = $config::MAIN_KEY if(! $key_name);
##	@{$self->{item_name_list}} = (@items[0..($data_start-1)], $key_name);	# set item_name 
##	my $kn = 0;
##	foreach my $k (@items[0..($data_start-1)], $key_name){
##		#dp::dp "$k: $kn\n";
##		$self->{item_name_hash}->{$k} = $kn++;
##	}

##	my $key_name = $self->{key_name} // "";			# set key name as "key" or $self->{key_name}
##	$key_name = $config::MAIN_KEY if(! $key_name);
	$self->add_key_items([$config::MAIN_KEY, @items[0..($data_start-1)], "item"]);

	#dp::dp join(",", "# " , @key_list) . "\n";
	dp::dp "load_transaction: " . join(", ", @items) . "\n";

	my $added_key = select::added_key($self);
	my $dt_end = -1;
	while(<FD>){
		#dp::dp $_;
		my (@vals)  = util::csv($_);

		$vals[0] += 2000 if($vals[0] < 100);
		my $ymd = sprintf("%04d-%02d-%02d", $vals[0], $vals[1], $vals[2]);		# 2020/01/03 Y/M/D

		if($dt_end < 0 || ($date_list->[$dt_end] // "") ne $ymd){
			$date_list->[++$dt_end] = $ymd;
		}

		my @gen_key = ();			# Generate key
		foreach my $n (@keys){
			if($n =~ /\D/){			# not number
				my $nn = $self->{item_name_hash}->{$n} // -1;
				if($nn < 0){
					dp::WARNING "key: no defined key[$n] " . join(",", @keys) . "\n";
				}
				$n = $nn - 1;		# added "mainkey" and "item"
			}
			#dp::dp "$n: " . csvlib::join_array(",", @vals) . "\n";
			my $itm = $vals[$n];
			push(@gen_key, $itm);
		}
		#dp::dp "$ymd: " . join(",", @gen_key) . "\n";

		#
		#		year,month,prefJ,PrefE,testedPositive,PeopleTested,Hospitalzed....
		#		2020,2,東京,Tokyo,3,130,,,,,
		#
		for(my $i = $data_start; $i <= $#items; $i++){
			my $item_name = $items[$i];
			my $master_key = join($key_dlm, @gen_key, $item_name) . $added_key;				# set key_name
			if(! defined $csv_data->{$master_key}){
				#dp::dp "load_transaction: assinge csv_data [$master_key]\n";

				$self->add_record($master_key,
						 [$master_key, @vals[0..($data_start-1)], $item_name], []);		# add record without data
			}
			my $v = $vals[$i] // 0;
			$v = 0 if(!$v || $v eq "-");
			$csv_data->{$master_key}->[$dt_end] = $v;
			#dp::dp "load_transaction: $ymd " . join(",", $k, $dt_end, $v, "#", @{$csv_data->{$k}}) . "\n";
		}
	}
	close(FD);
	dp::dp "##### data_end at transaction: $self->{id} $dt_end: $date_list->[$dt_end]\n";

	#
	#	Set unassgined data with 0
	#
	foreach my $k (keys %$csv_data){
		my $dp = $csv_data->{$k};
		for(my $i = 0; $i <= $dt_end; $i++){
			$dp->[$i] = $dp->[$i] // 0;
		}
	}

	$self->{dates} = $dt_end;
	$FIRST_DATE = $date_list->[0];
	$LAST_DATE = $date_list->[$dt_end];

	return 0;
}

#
#	Cumrative data to daily data
#
sub	cumrative2daily
{
	my $self = shift;

	my $csv_data = $self->{csv_data};

	foreach my $k  (keys %$csv_data){
		my $dp = $csv_data->{$k};
		#dp::dp "##" . join(",", $k, $csv_data, $dp) . "\n";
		my $dates = scalar(@$dp) - 1;
		for(my $i = $dates; $i > 0; $i--){
			$dp->[$i] = $dp->[$i] - $dp->[$i-1];
		}
	}
}

1;
