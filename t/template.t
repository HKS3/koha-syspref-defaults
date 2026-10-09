use strict;
use warnings;
use utf8;
use Test::More;
use Template;
use FindBin;
use lib "$FindBin::Bin/..";
use Koha::Plugin::HKS3::SysprefDefaults::I18N;

my %blocks = map { $_ => '' } qw(doc-head-open.inc doc-head-close.inc header.inc cat-search.inc intranet-bottom.inc);
my $tt = Template->new({ABSOLUTE=>1, ENCODING=>'utf8', BLOCKS=>\%blocks});
my $template = "$FindBin::Bin/../Koha/Plugin/HKS3/SysprefDefaults/tool.tt";
my $out = '';
for my $language (qw(de en)) {
my $strings = Koha::Plugin::HKS3::SysprefDefaults::I18N->catalog($language)->{strings};
$out='';
ok $tt->process($template, {
    i18n=>$strings,plugin_language=>$language,
    code_version=>'26.06.00.017',db_version=>'26.05',version_mismatch=>1,csp_nonce=>'safe-nonce',
    rows=>[{name=>'OPACUserJS',current=>'<script>alert("x")</script>',default=>'a & b',override=>'<img src=x>',status=>'changed'}],
    counts=>{},total=>1,
},\$out), 'render real template' or diag $tt->error;
unlike $out, qr/<script>alert|<img src=x>/, 'stored HTML/JS cannot execute';
like $out, qr/&lt;script&gt;/, 'HTML escaped';
like $out, qr/a &amp; b/, 'ampersand escaped';
like $out, qr/\Q$strings->{version_mismatch}\E/, "$language version mismatch shown";
like $out, qr/<h1>\Q$strings->{title}\E<\/h1>/, "$language title";
like $out, qr/lang="$language"/, 'plugin content language marked';
like $out, qr/data-one="\Q$strings->{visible_one}\E"/, 'translated singular counter';
like $out, qr/data-other="\Q$strings->{visible_other}\E"/, 'translated plural counter';
like $out, qr/option value="differences"/, 'default difference filter';
like $out, qr/<script nonce="safe-nonce">/, 'CSP-compatible script';
$out='';
ok $tt->process($template,{comparison_error=>1,i18n=>$strings,plugin_language=>$language},\$out), 'error render';
like $out, qr/\Q$strings->{comparison_error}\E/, "$language actionable error";
unlike $out, qr/id="pref-defaults"/, 'no misleading empty results on failure';
}
$out='';
ok $tt->process($template,{comparison_error=>1,i18n=>{title=>'<script>unsafe</script>',comparison_error=>'"<img src=x>'}},\$out), 'render hostile translation';
unlike $out,qr/<script>unsafe|<img src=x>/,'catalog strings are HTML escaped, never executed';
done_testing;
