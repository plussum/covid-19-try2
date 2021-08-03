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

# set csvlib
sub	ja {return csvlib::join_array(@_);}

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
		#$download->($self);
		&{$self->{down_load}}($self, $p);
	}
	if(! $src_file){
		dp::WARNING "load_csv: no src_file information\n";
		return "";
	}
	if(! -e $src_file){
		dp::WARNING "load_csv: $src_file is not found\n";
		disp_caller(1..3);
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
	elsif($direct =~ /vertical_multi/i){
		$rc = load_csv_vertical_multi($self, $src_file);
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
	# $self->set_alias($self->{alias});		# move to load items

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
	$self->set_alias($self->{alias});		#

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
        if(/"/){
            s/"([^",]+), *([^",]+), *([^",]+)"/$1;$2;$3/g;  # ,"aa,bb,cc", -> aa-bb-cc
            s/"([^",]+), *([^"]+)"/$1-$2/g; # ,"aa,bb", -> aa-bb
            #dp::dp "[$_]\n" if(/Korea/);
        }

		my $line = $_;
		my @items = (split(/$src_dlm/, $line));
		#my $master_key = select::gen_record_key($key_dlm, \@key_order, ["masterkey", @items]);
		my $master_key = select::gen_record_key($key_dlm, \@key_order, ["", @items[0..($data_start-1)]]);		# 2021.07.08 .... vaccine
		#dp::dp "MASTER_KEY: [" .$master_key . "] " . join(",", @key_order) . "  : " .join(",", @items[0..($data_start-1)]) . "\n";

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
#	Load vetical multi item csv file
#

#
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
	my $date_col = $self->{date_col}//0;
	my $key_dlm = $self->{key_dlm}; 

	#
	#	set main key (item name) 
	#	vertical csv had only main key (1 key)
	#
	##my $key_name = $self->{key_name} // "";			# set key name as "key" or $self->{key_name}
	##$key_name = $config::MAIN_KEY if(! $key_name);
	$self->add_key_items([$config::MAIN_KEY]);
	$self->set_alias($self->{alias});		#
	#@{$self->{item_name_list}} = ($key_name);		# set item_name 
	#$self->{item_name_hash}->{$key_name} = 0;

	my @key_order = $self->gen_key_order($self->{keys});		# keys to gen record key

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
	for($ln = 0; $ln <= $item_name_line; $ln++){
		$line = <FD>;
	}
	$line =~ s/[\r\n]+$//;
	#$line = decode('utf-8', $line);

	#dp::dp "$line\n";

	if($line =~ /"/){
		$line =~ s/"([^",]+), *([^",]+), *([^",]+)"/$1;$2;$3/g;  # ,"aa,bb,cc", -> aa-bb-cc
		$line =~ s/"([^",]+), *([^"]+)"/$1-$2/g; # ,"aa,bb", -> aa-bb
		#dp::dp "[[[[[[[$_]]]]]]]]]]\n";
	}
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
		my (@items) = split(/$src_dlm/, $line);
		my $date = $items[$date_col];
	
		#dp::dp "$date, [$src_dlm]" . join(",", @items) ."\n";
		$date_list->[$ln] = util::timefmt($timefmt, $date);
		#dp::dp "date:$ln $date " . $date_list->[$ln] . " ($timefmt) $self->{title}\n";
		#my @w = ($date);	
		my $k = select::gen_record_key($key_dlm, \@key_order, ["", @items]);		# 2021.07.08 .... vaccine
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
#	Load vetical multi item csv file
#
# location,iso_code,date,total_vaccinations,people_vaccinated,people_fully_vaccinated,
# 	daily_vaccinations_raw,daily_vaccinations,total_vaccinations_per_hundred,
#	people_vaccinated_per_hundred,people_fully_vaccinated_per_hundred,daily_vaccinations_per_million
# Japan,JPN,2021-04-12,1693683,1132778,560905,,70971,1.34,0.9,0.44,561
# Japan,JPN,2021-04-13,1751347,1150352,600995,57664,66112,1.38,0.91,0.48,523
# Japan,JPN,2021-04-14,1806491,1164069,642422,55144,59055,1.43,0.92,0.51,467
# Japan,JPN,2021-04-15,1866243,1187838,678405,59752,54091,1.48,0.94,0.54,428
# Japan,JPN,2021-04-16,1943875,1225479,718396,77632,50194,1.54,0.97,0.57,397
#
#							2021-01-01, 2021-01-02
# Japan, total_vaccinations
# Japan, people_vaccinated
# Japan, people_fully_vaccinated
# Japan, total_vaccinations_per_hundred
#

#
#			key1,key2,key3,
#	01/01
#	01/02
#	01/03
#
#	"key" 01/01, 01/02, 01/03
#	key1, 1,2,3
#	key2, 11,12,13
#	key3, 21,22,23
#
sub load_csv_vertical_multi
{
	my $self = shift;
	my ($src_file) = @_;

	my $verbose = 1;
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
	my $date_col = $self->{date_col}//0;
	my $key_dlm = $self->{key_dlm}; 
	my $item_name_hash = $self->{item_name_hash};

	#
	#	set main key (item name) 
	#	vertical csv had only main key (1 key)
	#
	##my $key_name = $self->{key_name} // "";			# set key name as "key" or $self->{key_name}
	##$key_name = $config::MAIN_KEY if(! $key_name);
	$self->add_key_items([$config::MAIN_KEY]);
	$self->set_alias($self->{alias});		#


	#
	#	Load CSV DATA
	#
	dp::dp "LOAD:$src_file\n";
	open(FD, "$src_file" ) || die "Cannot open $src_file";
	binmode(FD, ":utf8");
	#binmode(FD, ":encording(cp932)");

	#
	#	load item names
	#
	my $ln = 0;
	my $line = "";
	for($ln = 0; $ln < $item_name_line; $ln++){
		$line = <FD>;
	}
	$line =~ s/[\r\n]+$//;
	#$line = decode('utf-8', $line);

	#dp::dp "$line\n";

	if($line =~ /"/){
		$line =~ s/"([^",]+), *([^",]+), *([^",]+)"/$1;$2;$3/g;  # ,"aa,bb,cc", -> aa-bb-cc
		$line =~ s/"([^",]+), *([^"]+)"/$1-$2/g; # ,"aa,bb", -> aa-bb
		#dp::dp "[[[[[[[$_]]]]]]]]]]\n";
	}
	my @item_names = split(/$src_dlm/, $line);
	if($#item_names <= 1){
		dp::WARNING "may be wrong delimitter [$src_dlm]\n\n";
	}
	my @load_flag = ();
	for(my $i = 0; $i < $#item_names; $i++){
		$load_flag[$i] = "";
		$item_name_hash->{$item_names[$i]} = $i;
	}
	foreach my $col (@$load_col){
		my $i = $col;
		if($col =~ /\D/){
			$i = $item_name_hash->{$i} // dp::ABORT "undefined item: $i\n";
		}
		dp::dp "[$col] [$i]\n";
		$load_flag[$i] = 1;
	}
	my $keys = $self->{keys};
	my @key_order = $self->gen_key_order($self->{keys});		# keys to gen record key
	dp::dp "keys:      " .join(",", @$keys) . "\n";
	dp::dp "key_order: " .join(",", @key_order) . "\n";
	my $n = 0;
	@{$self->{item_name_list}} = ();		# set item_name 
	foreach my $kname (@keys){
		if(!($kname =~ /\D/)){
			$kname = $item_names[$kname] // dp::ABORT "$kname undefined\n";
		}
		push(@{$self->{item_name_list}}, $kname);		# set item_name 
		$self->{item_name_hash}->{$kname} = $n++;
	}

	#
	#	Skip non data row
	#
	for($ln++; $ln < $data_start_line; $ln++){		# skip lines until data_start_line
		<FD>;
	}

	#
	#	Load dated data
	#
	$ln = 0;
	my $date_no = 0;
	my %date_col = ();
	my $date = "";
	my $FIRST_DATE = "9999-99-99";
	my $LASt_DATE = "";
	my $csv_load = {};
	while(<FD>){
		s/[\r\n]+$//;
		my (@items) = split(/$src_dlm/, $_);
		$date = $items[$date_col];
		$date = util::timefmt($timefmt, $date);
		if(! defined $date_col{$date}){
			$date_col{$date} = $date_no++;
		}
		my $dt = $date_col{$date};
		$FIRST_DATE = $date if($date lt $FIRST_DATE);
		$LAST_DATE = $date if($date ge $LAST_DATE);

		for(my $i = $#items  + 1; $i <= $#item_names; $i++){
			push(@items, "");
		}
#		dp::dp "record: ";
#		for(my $i = 0; $i <= $#items; $i++){
#			print "$i:$items[$i] ";
#		}
#		print "\n";
		
		my @ids = ();		# for debug
		my @vals = ();		# for debug
		for(my $i = 0; $i <= $#items; $i++){
			next if(! $load_flag[$i]);				# check load flag

			my @item_key = ();						# generate keys
			for(my $jk = 0; $jk <= $#key_order; $jk++){
				my $k = $keys->[$jk];
				my $item = "";
				if($k eq "" || $k eq "item_name"){		# set item_name as a key of the record
					$item = $item_names[$i];		# location,iso_code,date,total_vaccinations,people_vaccinated,people_fully_vaccinated
				}
				else {
					if($k =~ /\D/){					# ex. location => 0
						$k = $item_name_hash->{$k} // dp::ABORT "item[$k] not defined\n";
					}
					$item = $items[$k];		# set item names[$k] as a key of the record
				}
				push(@item_key, $item);
			}
			my $k = select::gen_record_key($key_dlm, \@key_order, [@item_key]);

			my $v = $items[$i] // 0;
			$v = 0 if(! $v);
			$csv_load->{$k}->{$date}= $v;
			#dp::dp "[$k] $date -> " . $items[$i] . "[" . join(",", @item_key) . "]\n";
			#dp::dp "$i [$k] $date [$dt] -> " . $v . "\n";
			push(@ids, $item_key[1]);
			push(@vals, $v);
		}
		#dp::dp join("#", $items[0], @ids). " -> " . join(",", @vals) . "\n";
		#dp::dp $items[0] . ":$date -> " . join(",", @vals) . "\n" if($verbose);
		$ln++;
	}
	close(FD);

	my @key_list = (keys %$csv_load);
	my $first_dt = csvlib::ymds2tm($FIRST_DATE);
	for(my $dt = 0; $dt < $date_no; $dt++){
		my $date = csvlib::ut2date($first_dt + $dt * 60 * 60 * 24);
		$date_list->[$dt] = $date;
	}
	$self->{dates} = $date_no - 1;

	dp::dp "date_no: $date_no $FIRST_DATE keys : " . $#key_list . "\n";
	my $kn = 0;
	#dp::dp "load_end,, build_csv_data\n";
	foreach my $key (keys %$csv_load){
		#dp::dp $kn++ . "/" . $#key_list . ":$key\n";
		my @data = ();
		for(my $dt = 0; $dt < $date_no; $dt++){
			my $date = $date_list->[$dt];
			$data[$dt] = $csv_load->{$key}->{$date} // "NaN"; 
		}
		my @key_list = split(/$key_dlm/, $key);
		$self->add_record($key, [@key_list], [@data]);		# add record with data
	}
	#dp::dp "done\n";
	return 0;
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
	$self->set_alias($self->{alias});		#
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

	#
	#	Set items
	#
	my $line = <FD>;
	$line =~ s/[\r\n]+$//;
	my @items = util::csv($line);
	if( (defined $self->{item_names}) && scalar($self->{item_names} > 1)){
		my $items_rew = $self->{item_names};
		dp::dp "itemnames: " . join(",", @items) . "\n";
		my $alias_auto = {};
		for(my $i = 0; $i <= $#items; $i++){
			my $item_org = $items[$i];
			my $item_rew = $items_rew->[$i];
			$alias_auto->{$item_org} = $i + 1;
			$alias_auto->{$item_rew} = $i + 1;
			dp::dp "[$item_org][$item_rew]\n";
		}
		@items = @{$self->{item_names}};
		#dp::dp "itemnames: " . csvlib::join_array(",", @items) . "\n";
		$self->set_alias($alias_auto);		#
		#dp::dp "alias_auto: " . csvlib::join_array(",", $alias_auto) . "\n";
		#dp::dp csvlib::join_array(",", $self->{alias}) . "\n";
	}
	my @add_key_item = ();
	my @add_key_val = ();
	my %add_key_hash = ();
	if(defined $self->{add_keys}){
		foreach my $ak (@{$self->{add_keys}}){
			my ($item, $v) = split(/ *= */, $ak);
			push(@add_key_item, $item);
			push(@add_key_val, $v);
			$add_key_hash{$item} = $v;
		}
	}
	#dp::dp "add_key: " . join(",", @add_key_val) . "\n";
	$self->add_key_items([$config::MAIN_KEY, @items[0..($data_start-1)], "item", @add_key_item]);		# "item_name"

	$self->set_alias($self->{alias});		#
	#dp::dp csvlib::join_array(",", $self->{alias}) . "\n";

	#dp::dp join(",", "# " , @key_list) . "\n";
	#dp::dp "load_transaction: " . join(", ", @items) . "\n";

	#	Set key to key number
	my @keys_no = ();
	my $static = 0;
	my @static_val = ();
	foreach my $n (@keys){
		#if($n =~ /=/){
		#	my($item, $val) = split(/ *= */, $n);
		#	my $nn = $self->{item_name_hash}->{$item} // -1;
		#	if($nn < 0){
		#		dp::WARNING "key: no defined key[$n] " . join(",", @keys) . "\n";
		#	}
		#	$n = --$static;
		#	push(@static_val, $val);
		#}
		dp::dp "keys [$n]\n";
		if($n =~ /\D/){			# not number
			if(defined $add_key_hash{$n}){
				dp::dp "add_key_hash [$n]   $add_key_hash{$n}\n";
			}
			elsif(defined $self->{item_name_hash}->{$n}){
				my $nn = $self->{item_name_hash}->{$n};
				dp::dp "[[$nn]]\n";
				$n = $nn;  # - 1;		# added "mainkey" and "item"
			}
			else {
				dp::WARNING "key: no defined key[$n] " . join(",", @keys) . "\n";
			}
			dp::dp "key [$n]\n";
		}
		push(@keys_no, $n);
	}
	my $added_key = ""; #select::added_key($self);

	my $dt_end = 0;
	my %date_col = ();
	my $ln = 0;
	my $dt_start = -1;
	while(<FD>){
		#dp::dp $_;
		my (@vals)  = util::csv($_);

		my @date = ();
		if($self->{timefmt} eq '%Y/%m/%d'){			# comverbt to %Y-%m-%d
			@date = split(/\//, $vals[0]);
		}
		elsif($self->{timefmt} eq '%Y:0-%m:1-%d:2'){
			push(@date, $vals[0], $vals[1], $vals[2]);
		}		# comverbt to %Y-%m-%d
		#dp::dp join(", ", @vals) . "\n";
		#exit;

		$date[0] += 2000 if($date[0] < 100);
		my $ymd = sprintf("%04d-%02d-%02d", $date[0], $date[1], $date[2]);		# 2020/01/03 Y/M/D

		my $dt_sn = int(csvlib::ymd2tm($date[0], $date[1], $date[2], 0, 0, 0) / (24 * 60 * 60));
		$dt_start = $dt_sn if($dt_start < 0);
		my $dt = $dt_sn - $dt_start;
		#dp::dp "dt: $dt, $dt_sn, $dt_start\n";
		$date_list->[$dt] = $ymd;
		$dt_end = $dt if($dt > $dt_end);
		$date_col{$ymd} = $dt;
		#if(! defined $date_col{$ymd}){
		#	$date_col{$ymd} = $dt_end;
		#	$dt_end++ = $ymd;
		#}

		my @gen_key = ();			# Generate key
		foreach my $n (@keys_no){
			my $v = 0; 
			if($n =~ /^\D/){
				$v = $n;
			}
			else {	
				$v =  $vals[$n-1]//"UNDEF";
			}
			push(@gen_key, $v);
			#dp::dp ">>>> [$n] $v " . join(",", $vals[$n-1]//"-UNDEF-", @keys) . "\n";
		}
		
		#dp::dp "$ymd: " . &ja(",", @gen_key) . "  #   " . &ja(",", @keys_no) . "   |   " . &ja(",", @vals) . "\n" ;# if($ln++ < 9999);

		#
		#
		for(my $i = $data_start; $i <= $#items; $i++){
			my $item_name = $items[$i];
			my @mks = ($item_name);
			push(@mks, @add_key_val) if($#add_key_val >= 0);
			#dp::dp csvlib::join_array($key_dlm, @gen_key, @mks) . "\n";
			my $master_key = join($key_dlm, @gen_key, @mks);				# set key_name
			if(! defined $csv_data->{$master_key}){
				#dp::dp "load_transaction: assinge csv_data [$master_key]\n";

				$self->add_record($master_key,
						 [$master_key, @vals[0..($data_start-1)], @mks], []);		# add record without data
			}
			my $v = $vals[$i];
			#dp::dp "[$master_key] $v\n";
			#my $v = $vals[$i] // 0;
			$v = 0 if(!$v || $v eq "-");

			my $dcol = $date_col{$ymd};
			$csv_data->{$master_key}->[$dcol] = $v;
			#dp::dp "[$master_key] $v\n";
			# dp::dp "$ymd " . "[$master_key] = $v  ($dt_end)" . "\n"; #, @{$csv_data->{$master_key}}) . "\n";
		}
	}
	close(FD);
	#dp::dp "##### data_end at transaction: $self->{id} $dt_end: $date_list->[$dt_end]\n";
	for(my $i = 0; $i <= $dt_end; $i++){
		next if(defined $date_list->[$i]);

		my $dt = $dt_start + $i * 24 * 60 * 60;
		my $ymd = csvlib::ut2d($dt, "-");
		$date_list->[$i] = $ymd;
		dp::dp "set $ymd\n";
		foreach my $mk (keys %$csv_data){
			my $cdpw = $csv_data->{$mk};
			$cdpw->[$i] = "NaN";
		}
	}

	#
	#	Set unassgined data with 0
	#
	foreach my $k (keys %$csv_data){
		my $dp = $csv_data->{$k};
		for(my $i = 0; $i <= $dt_end; $i++){
			$dp->[$i] = $dp->[$i] // 0;
		}
		#dp::dp join(",", "$k: ", @{$csv_data->{$k}}) . "\n";
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
		$dp->[0] = 0 if($self->{cumrative} eq "init0");
	}
}

1;
