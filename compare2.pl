#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use File::Spec;


# perl compare.pl \
#--golden=golden \
#  --result=result \
#  --fields=Voltage,Delay,Power \
#  --tolerance=0.02 \
#  --output=report.txt

my ($golden_file_dir, $result_file_dir, $keyword, $output_file, $tolerance, $help);

GetOptions(
    'golden=s' => \$golden_file_dir,
    'result=s' => \$result_file_dir,
    'fields=s' => \$keyword,
    'output=s' => \$output_file,
    'tolerance=f'=> \$tolerance,
    'help' => \$help,
) or die "wrong parameter, please use --help\n";

if (!defined $tolerance) {
    $tolerance = 0.01;
}

if (!defined $output_file) {
    $output_file = 'compare.txt';
}

if($help) {
    print <<"USAGE";
Usage:
    perl compare.pl --golden=<file_dir> --result=<result_file_dir> --fields=<key> [--output=<file>] [--tolerance=<float>]]
Description:
    --golden Golden file dir
    --result Result file dir
    --fields Field name to compare (Voltage, Current)
    --output Output file (default compare.txt)
    --tolerance Allowable error (default 0.01)
    --help Show help
USAGE
    exit;
}

die "please specify --golden, --result, --fields\n"
    unless defined $golden_file_dir && defined $result_file_dir && defined $keyword;

warn "keyword: $keyword\n"; 

my $mode = 0; # 0: file, 1: dir
if (-f $golden_file_dir && -f $result_file_dir) {
    $mode = 0;
} elsif (-d $golden_file_dir && -d $result_file_dir) {
    $mode = 1;
} else {
    die "❌ --golden 和 --result 必須同為檔案或同為資料夾\n";
}
my %golden_hash;
my %result_hash;

if ($mode == 1) {
    my @golden_files = get_file_list($golden_file_dir);
    my @result_files = get_file_list($result_file_dir);
    foreach my $golden_file (@golden_files) {
        open(my $golden_fh, '<', File::Spec->catfile($golden_file_dir, $golden_file)) or die "cannot read $golden_file: $!";
            while (my $line = <$golden_fh>) {
                if ($line =~ /(\w+)\s*[:=]\s*(-?\d+(?:\.\d+)?)/) {
                    $golden_hash{lc($1)} = $2;
                }
        }
        close($golden_fh);
    }
    print "golden_files: @golden_files\n";
    print "result_files: @result_files\n";
    foreach my $result_file (@result_files) {
        open(my $result_fh, '<', File::Spec->catfile($result_file_dir, $result_file)) or die "cannot read $result_file: $!";
            while (my $line = <$result_fh>) {
                if ($line =~ /(\w+)\s*[:=]\s*(-?\d+(?:\.\d+)?)/) {
                    $result_hash{lc($1)} = $2;
                }
        }
        close($result_fh);
    }
} else {
    open (my $golden_fh, '<', $golden_file_dir) or die "cannot read $golden_file_dir: $!";
    while (my $line = <$golden_fh>) {
        if ($line =~ /(\w+)\s*[:=]\s*(-?\d+(?:\.\d+)?)/) {
            $golden_hash{lc($1)} = $2;
        }
    }
    close($golden_fh);
    open (my $result_fh, '<', $result_file_dir) or die "cannot read $result_file_dir: $!";
    while (my $line = <$result_fh>) {
        if ($line =~ /(\w+)\s*[:=]\s*(-?\d+(?:\.\d+)?)/) {
            $result_hash{lc($1)} = $2;
        }
    }
}

open(my $output_fh, '>', $output_file) or die "cannot open the file $output_file: $!";
my $has_fail = 0;
for my $raw_key (split /,/, $keyword) {
    $raw_key =~ s/^\s+|\s+$//g;
    my $key = lc($raw_key);
    if(exists $golden_hash{$key} && exists $result_hash{$key}) {
        my $g = $golden_hash{$key};
        my $r = $result_hash{$key};
        my $diff = abs($g - $r);
        my $status = ($diff <= $tolerance) ? "PASS" : "FAIL";
        $has_fail = 1 if $status eq "FAIL";

        print $output_fh <<"RESULT";
[$status] $raw_key
Golden = $g
Result = $r
Difference = $diff
RESULT
    }
    else {
        print $output_fh "[$raw_key] not found in golden or result file\n";
        $has_fail = 1;
    }
}
close($output_fh);

print "compare done, please check $output_file\n";

if ($has_fail) {
    print "❌ Compare finished with FAIL(s). Check $output_file\n";
} else {
    print "✅ All fields passed. Output in $output_file\n";
}

exit($has_fail);

sub get_file_list {
    my ($dir) = @_;
    opendir(my $dh, $dir) or die "cannot open directory $dir: $!";
    my @files = grep { /\.txt$/ && -f File::Spec->catfile($dir, $_)} readdir $dh;
    closedir ($dh);
    return @files;
}
