#
#
#
package reduce;
use Exporter;
@ISA = (Exporter);
@EXOIORT = qw(reduce);

use strict;
use warnings;
use utf8;
use Encode 'decode';
use JSON qw/encode_json decode_json/;
use Clone qw(clone);
use Data::Dumper;

use config;
use csvlib;
use dump;
use util;
use csv2graph;

my $DEBUG = 0;
my $VERBOSE = 0;
my $dumpf = 0;


#
#
#
##sub	reduce_cdp_target
##{
##	my $self = shift;
##	my ($target_colp) = @_;
##
##	my $dst_cdp = {};
##	return &reduce_cdp_target_a($self, $dst_cdp,$target_colp);
##}


#
#
#
sub	reduce_cdp_target
{
	my $self = shift;
	my ($target_colp) = @_;

	#dp::dp Dumper $target_colp;
	$target_colp = $target_colp // "";

	my @target_keys = ();
	#dp::dp "reduce_cdp_target: $target_colp " . csvlib::join_array(",", $target_colp) . "\n";
	@target_keys = $self->select_keys($target_colp);
	#dp::dp "result of select(", $#target_keys, ") " . join(",", @target_keys) . "\n";
	if($#target_keys < 0){
		my $tgps = ($target_colp) ? csvlib::join_array(",", $target_colp) : "null";
		dp::ABORT "No data " . $tgps . "##" . join(",", @target_keys). "\n";
	}
	#my $ft = $target_colp->[0] ;
	#if(0 && $ft eq "NULL"){
	#	$dumpf = 1;
	#	#dp::dp "###### TARGET_KEYS #######\n";
	#	#dp::dp join("\n", @target_keys);
	#	#dp::dp "################\n";
	#}
	my $dst_cdp = $self->reduce_cdp(\@target_keys);
	$dst_cdp->dump({ok => 1, lines => 20, items => 20}) if($DEBUG);

	return $dst_cdp;
}

sub	reduce_cdp
{
	my $self = shift;
	my($target_keys) = @_;


	my $all_key = [];
	if((!defined $target_keys) || $target_keys eq ""){
		$target_keys = $all_key;
		@$target_keys = keys %{$self->{csv_data}};
		#dp::dp join(",", @$target_keys) . "\n";
	}
	my $dst_cdp = clone($self);
	$dst_cdp->remove_data();					# remove csv and related data
	#dp::dp join(",", $self->{key_items}, $self->{csv_data}) . "\n";
	foreach my $key (@$target_keys){			# set target data from source cdp (self)
		$dst_cdp->add_record($key, $self->{key_items}->{$key}, $self->{csv_data}->{$key});
	}

	if($DEBUG){
		my $kn = 0;
		my $dst_csv = $dst_cdp->{csv_data};
		foreach my $key (keys %$dst_csv){
			last if($kn++ > 5);

			#dp::dp "############ $key\n" if($key =~ /Canada/);
			#dp::dp "csv[$key] " . join(",", @{$dst_csv->{$key}}[0..5]) . "\n";
			#dp::dp "key[$key] " . join(",", @{$dst_key->{$key}}[0..5]) . "\n";
		}
		$dst_cdp->dump_cdp({ok => 1, lines => 20, items => 20, search_key => "Canada"}); # if($DEBUG);
	}
	return  $dst_cdp;
}

#
#	Copy and Reduce CSV DATA with replace data set
#
sub	dup
{
	my $self = shift;
	
	#csv2graph::dump_cdp($cdp, {ok => 1, lines => 5});

	my $dst_cdp = clone($self);
##	my $dst_cdp = {};
##	&reduce_cdp($dst_cdp, $cdp, ""); 

	return $dst_cdp;
}

sub	dup_csv
{
	my $self = shift;
	my ($target_keys) = @_;

	my $src_csv = $self->{csv_data};
	my $dst_csv = {};

	if(($target_keys // "")){						# when target key [] was sat
		$dst_csv = clone($src_csv);
	}
	else {
		foreach my $key (@$target_keys){			# set target data from source cdp (self)
			$dst_csv->{$key} =  $src_csv->{$key};
		}
	}

	return $dst_csv;

##
##	my $work_csv = {};
##
##	my $csv_data = $cdp->{csv_data};
##	#dp::dp "dup_csv: cdp[$cdp] csv_data : $csv_data\n";
##	$target_keys = $target_keys // "";
##	if(! $target_keys){
##		my @tgk = ();
##		my $csv_data = $cdp->{csv_data};
##		#dp::dp ">>dup_csv cdp[$cdp] csv_data[$csv_data]\n";
##		foreach my $k (keys %$csv_data){
##			push(@tgk, $k);
##		}
##		#@$target_keys = (keys %$csv_data);
##		#dp::dp "DUP.... " . join(",", @tgk) . "\n";
##		$target_keys = \@tgk;
##		#exit;
##	}
##	foreach my $key (@$target_keys){						#
##		$work_csv->{$key} = [];
##		#dp::dp "$key: $csv_data->{$key}\n";
##		push(@{$work_csv->{$key}}, @{$csv_data->{$key}});
##	}
##	return $work_csv;
}

1;
