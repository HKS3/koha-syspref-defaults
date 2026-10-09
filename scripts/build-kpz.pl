#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use File::Find;
use File::Path qw(make_path);
use File::Spec;
use Cwd qw(abs_path);
use IO::Compress::Zip qw($ZipError ZIP_CM_DEFLATE);

my $root = abs_path("$FindBin::Bin/..");
chdir $root or die "Cannot enter project directory: $!";
open my $module,'<','Koha/Plugin/HKS3/SysprefDefaults.pm' or die $!;
my $source=do {local $/; <$module>};
my ($version)=$source =~ /our \$VERSION = '([0-9.]+)'/;
die "Version missing\n" unless $version;
my @files;
find({no_chdir=>1,wanted=>sub {push @files,$File::Find::name if -f && !-l;}},'Koha');
push @files, 'README.md', 'README.de.md', 'LICENSE';
@files=sort @files;
make_path('dist');
my $target="dist/koha-syspref-defaults-$version.kpz";
my $zip;
for my $path (@files) {
    if (!$zip) {
        $zip=IO::Compress::Zip->new($target,Name=>$path,Method=>ZIP_CM_DEFLATE,Time=>315532800) or die $ZipError;
    } else {
        $zip->newStream(Name=>$path,Method=>ZIP_CM_DEFLATE,Time=>315532800) or die $ZipError;
    }
    open my $in,'<:raw',$path or die $!;
    my $data=do {local $/; <$in>};
    $zip->print($data) or die $ZipError;
    close $in;
}
$zip->close or die $ZipError;
print "$root/$target\n";
