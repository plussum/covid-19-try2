#!/usr/bin/perl
#
#
use strict;
use warnings;
use utf8;
use Data::Dumper;
use config;
use csvlib;
use dp;

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

my $dlm = "\t";

my $WIN_PATH = $config::WIN_PATH;
my $HTML_PATH = "$WIN_PATH/HTML2",
my $PNG_PATH  = "$WIN_PATH/PNG2",
my $PNG_REL_PATH  = "../PNG2",
my $CSV_PATH  = $config::WIN_PATH;

my $CSS = $config::CSS;
my $class = $config::CLASS;

my $report_conff = "$WIN_PATH/report.txt";
my $report_htmlf = "$HTML_PATH/report.html";

my @LIST = ();
# file:///W:/cov/plussum.github.io/PNG2/沖縄県_pop_14_nc_40_0_nd_0_2_dr_0_34_0_0.png
open(FD, $report_conff) || die "cannot open $report_conff";
binmode(FD, ":utf8");
while(<FD>){
	chop;
	last if(/#INDEX DATA#/);

	s/[\s]*#.*//;
	# next if(! /\w/);

	s#.*/plussum.github.io/##;
	push(@LIST, $_);
}
my	@INDEX_DATA = ();
my $header = "";
my @headers = ();
my @TABLE_ITEM_ORDER = ();
my %TABLE_ITEM = ();
while(<FD>){
	chop;

	if(/^H:/){
		s/^H://;
		$header = $_;
		push(@headers, $header);
		next;
	}
	next if(! /file:/);

	#dp::dp "<<< $_";
	s/[\s]*#.*//;
	my($name, $line, $col, $file) = split(/,/, $_);
	$file =~ s#.*/plussum.github.io/##;
	push(@INDEX_DATA, {header => $header, name => $name, line => $line, col => $col, file => $file});
	#dp::dp "-- $header: $_\n";

	if(! defined $TABLE_ITEM{$name}){
		$TABLE_ITEM{$name}++;
		push(@TABLE_ITEM_ORDER, $name);
	}
}
close(FD);


#
#
#
my @INDEX = ();
my %TABLE_DATA = ();
foreach my $p (@INDEX_DATA){
	my $name = $p->{name};
	my $line = $p->{line};
	my $col = $p->{col};
	my $file = $p->{file};
	my $header = $p->{header};

	$file = "$WIN_PATH/$file";
	if(! -e $file){
		dp::dp "cannto find file $file\n";
		next;
	}
	my @lines = ();
	open(FD, $file) || die "cannot open $file";
	while(<FD>){
		push(@lines, $_);
	}
	close(FD);
	
	my $n = $line;
	if($line < 0){
		$n = $#lines + $line + 1;
	}
	if(!defined $lines[$n]){
		dp::dp "error no data in $n $line\n";
		next;
	}
	chop($lines[$n]);
	my @w = split(/$dlm/, $lines[$n]);
	my $v = $w[$col] // "-99999";
	$TABLE_DATA{$name} = {} if(! defined $TABLE_DATA{$name});
	$TABLE_DATA{$name}->{$header} = sprintf("%.3f", $v);
}

#
#
#
my $now = csvlib::ut2dt(time());
open(HTML, "> $report_htmlf") || die "Cannot create $report_htmlf";
binmode(HTML, ":utf8");
#binmode(HTML, ':encoding(cp932)');
print HTML "<html>\n<head>\n";
print HTML "<TITLE>COVID 19  [$now]</TITLE>\n";
print HTML "$CSS\n";
print HTML "</head>\n<body>\n";
print HTML "<span class=\"c\">\n";
print HTML $now . "<br>\n";

print HTML "<table border=\"1\">\n<tbody>\n";
print HTML "<tr>" . &tag("th", "-", @headers) . "</tr>";
foreach my $name (@TABLE_ITEM_ORDER){
	my @col = ($name);
	foreach my $header (@headers){
		push(@col, $TABLE_DATA{$name}->{$header}//"undef:$name:$header");
	}
	#dp::dp join(",", @col) . "\n";
	print HTML "<tr>" . &tag("td:align=\"right\"", @col) . "</tr>";
}
print HTML "</table>";

sub	tag
{
	my ($tag, @vals) = @_;
	$tag =~ s/[<>]//g;
	($tag, my $aln) = split(/:/, $tag);
	$aln = $aln // "";
	my $html = "";

	foreach my $v (@vals){
		$html .= "<$tag $aln>$v</$tag>";
	}
	#dp::dp "[$html]\n";
	return $html;
}
		


#
#	index
#
foreach my $index (@INDEX){
}
print HTML "</tbody>\n</table>\n";
print HTML "<br>\n";

#
#	graph
#	
my @header = ();
my @table = ();
foreach my $item (@LIST){

	if($item =~ /^H\d+/){
		my $h = $&;
		$item =~ s/$h\s*//;
		print HTML "<$h>$item</$h>\n";
	}
	elsif($item =~ /.png$/){
		if($#header >= 0){
			print HTML "<h2>" . join("<br>", @header) . "<h2>\n";
			@header = ();
		}
		push(@table, $item);
	}
	elsif(!$item || !($item =~ /\S/)){
		&out_image(@table);
		@table = ();
	}
	else {
		push(@header, $item);
	}
}
if($#table >= 0){
	&out_image(@table);
}

print HTML "</span>\n";
print HTML "<body>\n<html>\n";
close(HTML);




sub	out_image
{
	my (@table) = @_;

	print HTML "<table>\n";
	print HTML "<tbody>\n";
	print HTML "<tr>\n";
	foreach my $item (@table){
		print HTML "<td>\n";
		$item =~ s#.png##;
		my $html = "<img src=\"../$item.png\">\n";
		my $csvf = "$item" . "-plot.csv.txt";
		my $plotf = "$item" . "-plot.txt";
		print "ERROR: $WIN_PATH/$csvf\n" if(! -e "$WIN_PATH/$csvf");
		print "ERROR: $WIN_PATH/$plotf\n" if(! -e "$WIN_PATH/$plotf");

		$html .= "<br>\n";
		$html .= "<a href=\"../$item" . "-plot.csv.txt\">CSV</a>\n";
		$html .= "<a href=\"../$item" . "-plot.txt\">PLOT</a>\n";
		$html .= "<br>\n";
		print HTML $html . "\n";
		#print $html . "\n";
		print HTML "</td>\n";

	}
	print HTML "</tr>\n";
	print HTML "</tbody>\n";
	print HTML "</table>\n";
}
