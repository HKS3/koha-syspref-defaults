#!/usr/bin/env perl
# Run inside a configured Koha testing environment; no plugin installation.
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/..";
use Test::More;
use Template;
use C4::Context;
use Koha;
use Koha::Plugin::HKS3::SysprefDefaults;
use Koha::Plugin::HKS3::SysprefDefaults::Compare;

my $dbh=C4::Context->dbh;
$dbh->do('SET SESSION TRANSACTION READ ONLY');
$dbh->begin_work;
my $class='Koha::Plugin::HKS3::SysprefDefaults::Compare';
my $language=$ENV{PLUGIN_LANGUAGE} // 'en';
my $catalog=Koha::Plugin::HKS3::SysprefDefaults::I18N->catalog($language);
my $source=$class->read_defaults(C4::Context->config('intranetdir'));
my $current=$dbh->selectall_arrayref('SELECT variable,value FROM systempreferences',{Slice=>{}});
my $result=$class->compare($source->{defaults},$current,\%ENV,$catalog->{strings});
cmp_ok $result->{total},'>',500,'compare current KTD preferences with installed defaults';
my ($dbversion)=map {$_->{value}} grep {lc($_->{variable}) eq 'version'} @$current;
ok $class->version_matches(Koha::version(),$dbversion),'code and database version agree';
my $includes=C4::Context->config('intrahtdocs').'/prog/en/includes';
my $tt=Template->new({ABSOLUTE=>1,ENCODING=>'utf8',INCLUDE_PATH=>$includes,PLUGIN_BASE=>'Koha::Template::Plugin',EVAL_PERL=>1});
my $out='';
my $nonce=Koha::Template::Plugin::Koha->can('CSPNonce') ? Koha::Template::Plugin::Koha->CSPNonce : '';
ok $tt->process("$FindBin::Bin/../Koha/Plugin/HKS3/SysprefDefaults/tool.tt",{
    %$result, source_path=>$source->{path},source_sha256=>$source->{sha256},
    i18n=>$catalog->{strings},plugin_language=>$catalog->{language},
    code_version=>Koha::version(),db_version=>$dbversion,csp_nonce=>$nonce,
    interface=>'/intranet-tmpl',theme=>'prog',lang=>'en',footerjs=>1,
},\$out),'render with real Koha template includes' or diag $tt->error;
like $out,qr/id="pref-defaults"/,'comparison table present';
like $out,qr/<\/html>/,'complete document';
like $out,qr/\Q$catalog->{strings}{title}\E/,'localized title';
$dbh->rollback;
diag 'Koha '.Koha::version().'; defaults='.scalar(keys %{$source->{defaults}}).'; compared='.$result->{total}.'; render bytes='.length($out);
done_testing;
