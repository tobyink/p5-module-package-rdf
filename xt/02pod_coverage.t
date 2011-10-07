use Test::More;
use Test::Pod::Coverage;

my @modules = qw(Module::Package::RDF Module::Package::RDF::Create);
pod_coverage_ok($_, "$_ is covered")
	foreach @modules;
done_testing(scalar @modules);

