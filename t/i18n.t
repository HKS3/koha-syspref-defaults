use strict;
use warnings;
use utf8;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";
use JSON::PP;
use Koha::Plugin::HKS3::SysprefDefaults::I18N;
use Koha::Plugin::HKS3::SysprefDefaults::Compare;

my $class='Koha::Plugin::HKS3::SysprefDefaults::I18N';
for my $case ([undef,'en'],['en-GB','en'],['EN_us','en'],['de-DE','de'],['de_AT','de'],['fr-FR','en'],['../../de','en'],['de/../en','en']) {
    is $class->catalog($case->[0])->{language},$case->[1],'safe language resolution: '.($case->[0]//'undefined');
}
my %catalogs;
for my $language (qw(en de)) {
    open my $fh,'<:raw',"$FindBin::Bin/../Koha/Plugin/HKS3/SysprefDefaults/i18n/$language.json" or die $!;
    $catalogs{$language}=JSON::PP->new->utf8->decode(do {local $/; <$fh>});
    close $fh;
    ok !grep(!defined($_) || ref($_) || $_ eq '',values %{$catalogs{$language}}),"$language translations are nonempty strings";
    for my $key (qw(visible_one visible_other)) {
        is scalar(()=$catalogs{$language}{$key}=~/\{count\}/g),1,"$language $key has one count placeholder";
    }
}
is_deeply [sort keys %{$catalogs{de}}],[sort keys %{$catalogs{en}}],'German catalog covers every English key';
open my $tt,'<:encoding(UTF-8)',"$FindBin::Bin/../Koha/Plugin/HKS3/SysprefDefaults/tool.tt" or die $!;
my $template=do {local $/; <$tt>}; close $tt;
my %keys=map {$_=>1} $template=~/\bi18n\.([a-z_]+)/g;
ok exists $catalogs{en}{$_},"template key $_ exists" for sort keys %keys;
for my $language (qw(en de en)) {
    my $strings=$class->catalog($language)->{strings};
    my $result=Koha::Plugin::HKS3::SysprefDefaults::Compare->compare(
        {apikey=>{variable=>'APIKey',value=>'secret-before'},empty=>{variable=>'Empty',value=>undef}},
        [{variable=>'APIKey',value=>'secret-after'},{variable=>'Empty',value=>''},{variable=>'RealText',value=>'— leer —'}],{},$strings
    );
    my %rows=map {$_->{name}=>$_} @{$result->{rows}};
    is $rows{APIKey}{current},$strings->{value_masked},"$language masked marker";
    is $rows{Empty}{current},$strings->{value_empty},"$language empty marker";
    is $rows{Empty}{default},$strings->{value_null},"$language NULL marker";
    is $rows{Empty}{override},$strings->{value_absent},"$language absent marker";
    is $rows{RealText}{current},'— leer —','actual stored values are never translated';
    is $result->{counts}{changed},2,'translation does not change comparison';
    unlike(JSON::PP->new->encode($result),qr/secret-before|secret-after/,'secrets do not reach localized view model');
}
done_testing;
