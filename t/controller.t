use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/..";

# No Koha instance or database needed: all external boundaries are test doubles.
BEGIN {
    $INC{'Koha/Plugins/Base.pm'}=1;
    $INC{'C4/Auth.pm'}=1;
    $INC{'C4/Context.pm'}=1;
    $INC{'C4/Languages.pm'}=1;
    $INC{'Koha.pm'}=1;
    $INC{'Koha/Template/Plugin/Koha.pm'}=1;
    package Koha::Template::Plugin::Koha;
    sub CSPNonce { return 'test-nonce'; }
    package Koha::Plugins::Base;
    sub mbf_path { return 'tool.tt'; }
    sub output_html { $main::output_args=[@_]; }
    package C4::Auth;
    sub import { no strict 'refs'; *{caller().'::get_template_and_user'}=\&get_template_and_user; }
    sub get_template_and_user {
        $main::auth_args=$_[0];
        die "denied\n" unless $main::authorized;
        return (bless({},'Local::Template'),1,'cookie');
    }
    package C4::Context;
    sub config { return '/missing/defaults'; }
    sub dbh { die "DB must not be reached\n"; }
    package C4::Languages;
    sub import { no strict 'refs'; *{caller().'::getlanguage'}=\&getlanguage; }
    sub getlanguage { return $main::koha_language; }
    package Local::Request;
    sub param { return $main::plugin_language; }
    package Koha;
    sub version { '26.06.00.017'; }
    package Local::Template;
    sub param { shift; my %args=@_; @{$main::template_args}{keys %args}=values %args; }
    sub output { return 'rendered'; }
}

our ($output_args,$auth_args,$template_args,$authorized,$plugin_language);
our $koha_language='de-DE';
use Koha::Plugin::HKS3::SysprefDefaults;
my $plugin = bless({cgi=>bless({},'Local::Request')}, 'Koha::Plugin::HKS3::SysprefDefaults');
$authorized=0;
ok !eval {$plugin->tool; 1}, 'unauthorized request denied';
like $@,qr/denied/, 'auth before defaults or DB access';
is_deeply $auth_args->{flagsrequired},{parameters=>'manage_sysprefs'}, 'extra syspref permission enforced';
ok !$output_args, 'no output to denied caller';
$authorized=1;
ok eval {$plugin->tool; 1}, 'missing defaults handled';
is $template_args->{comparison_error},1,'failure flag';
is_deeply $output_args->[3],{force_no_caching=>1},'no-store response';
is $output_args->[4],'cookie','auth cookie forwarded';
is $template_args->{csp_nonce},'test-nonce','Koha CSP nonce propagated';
is $template_args->{footerjs},1,'standard Koha JS footer enabled';
is $template_args->{plugin_language},'de','Koha staff language selected';
like $template_args->{i18n}{title},qr/Systemeinstellungen/,'German catalog passed';
$plugin_language='en';
$plugin->tool;
is $template_args->{plugin_language},'en','explicit plugin language takes precedence';
like $template_args->{i18n}{title},qr/System preferences/,'English catalog passed';
$plugin_language=undef;
$koha_language='fr-FR';
$plugin->tool;
is $template_args->{plugin_language},'en','unsupported staff language falls back to English';

{
    no warnings 'redefine';
    local *Koha::Plugin::HKS3::SysprefDefaults::Compare::read_defaults = sub {
        return {path=>'/fixture/sysprefs.sql',sha256=>'0'x64,defaults=>{
            testpref=>{variable=>'TestPref',value=>'default'},
            apikey=>{variable=>'APIKey',value=>''},
        }};
    };
    local *C4::Context::dbh = sub {bless {},'Local::Database'};
    $template_args={};
    ok eval {$plugin->tool; 1},'authorized successful comparison';
    ok !$template_args->{version_mismatch},'real version formats agree';
    is $template_args->{counts}{changed},2,'controller comparison counts';
    is $template_args->{source_path},'/fixture/sysprefs.sql','provenance passed';
    use Data::Dumper;
    unlike Dumper($template_args),qr/private-credential/,'raw credential never reaches template';
}
done_testing;

package Local::Database;
sub selectall_arrayref {
    my ($self,$sql)=@_;
    die 'unexpected query' unless $sql eq 'SELECT variable, value FROM systempreferences ORDER BY variable';
    return [
        {variable=>'Version',value=>'26.0600017'},
        {variable=>'TestPref',value=>'configured'},
        {variable=>'APIKey',value=>'private-credential'},
    ];
}
