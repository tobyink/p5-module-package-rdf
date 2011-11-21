package Module::Package::RDF::Create;

use common::sense;

BEGIN {
	$Module::Package::RDF::Create::AUTHORITY = 'cpan:TOBYINK';
	$Module::Package::RDF::Create::VERSION   = '0.004';
}

use Carp;
use DateTime;
use IO::All;
use Software::License;
use Text::Template;
use URI::Escape qw[];

{
	my %templates;
	sub import
	{
		my ($class) = @_;
		
		my $key = undef;
		while (my $line = <DATA>)
		{
			if ($line =~ /^COMMENCE\s+(.+)\s*$/)
			{
				$key = $1;
			}
			else
			{
				$templates{$key} .= $line;
			}
		}
	}
	sub _get_template
	{
		my ($class, $key) = @_;
		return Text::Template->new(-type=>'string', -source=>$templates{$key});
	}
	sub _get_template_names
	{
		my ($class) = @_;
		return keys %templates;
	}
}

sub _fill_in_template
{
	my ($self, $template) = @_;
	$template = $self->_get_template($template) unless ref $template;
	
	my %hash;
	while (my ($k, $v) = each %$self)
	{
		$hash{$k} = ref $v ? \$v : $v;
	}
	
	return $template->fill_in(
		-hash => \%hash,
		);
}

sub _iofile
{
	my ($self, $file) = @_;
	my $basedir = sprintf($self->{destination}, $self->{dist_name});
	return io($basedir.$file)->assert;
}

sub create
{
	my ($class, $name, %options) = @_;
	
	$options{module_name} = $name;
	$options{dist_name}   = $name;
	
	if ($name =~ /::/)
	{
		$options{dist_name} =~ s/::/-/g;
	}
	elsif ($name =~ /\-/)
	{
		$options{module_name} =~ s/\-/::/g;
	}
	
	my %use;
	if (ref $options{use} eq 'ARRAY')
	{
		%use = map {$_=>1} @{$options{use}};
	}
	$options{use} = \%use;
	
	my $self = bless \%options, $class;
	
	$self->set_defaults;
	$self->create_module;
	$self->create_makefile_pl;
	$self->create_metadata;
	$self->create_tests;
	$self->create_author_tests;
}

sub set_defaults
{
	my ($self) = @_;
	
	croak "Need an author name."   unless defined $self->{author}{name};
	croak "Need an author cpanid." unless defined $self->{author}{cpanid};

	$self->{author}{cpanid} = lc $self->{author}{cpanid};
	$self->{author}{mbox} ||= sprintf('%s@cpan.org', $self->{author}{cpanid});

	$self->{backpan} ||= sprintf('http://backpan.cpan.org/authors/id/%s/%s/%s/',
		substr(uc $self->{author}{cpanid}, 0, 1),
		substr(uc $self->{author}{cpanid}, 0, 2),
		uc $self->{author}{cpanid},
		);
	
	$self->{abstract} ||= 'a module that does something-or-other';
	$self->{version}  ||= '0.001';
	
	$self->{version_ident} = 'v_'.$self->{version};
	$self->{version_ident} =~ s/\./-/g;
	
	$self->{destination} ||= './%s/';
	
	unless ($self->{module_filename})
	{
		$self->{module_filename} = 'lib::'.$self->{module_name};
		$self->{module_filename} =~ s/::/\//g;
		$self->{module_filename} .= '.pm';
	}
	
	$self->{copyright}{holder} ||= $self->{author}{name};
	$self->{copyright}{year}   ||= DateTime->now->year;
	
	$self->{licence_class} ||= 'Software::License::Perl_5'; 
	eval sprintf('use %s;', $self->{licence_class});
	$self->{licence} = $self->{licence_class}->new({
		year    => $self->{copyright}{year},
		holder  => $self->{copyright}{holder},
		});
	
	# 'includes' is 'use' minus some modules we handle specially
	$self->{includes} = [grep {!/^(autodie|boolean|common_sense|strict|warnings|moose|5\.[0-9_]+|namespace_clean)$/} keys %{$self->{use}}];
	
	{
		my @mr = @{ $self->{includes} };
		push @mr, 'Moose'            if $self->{use}{moose};
		push @mr, 'autodie'          if $self->{use}{autodie};
		push @mr, 'boolean'          if $self->{use}{boolean};
		push @mr, 'common::sense'    if $self->{use}{common_sense};
		push @mr, 'namespace::clean' if $self->{use}{namespace_clean}
		                             || $self->{use}{moose};
		
		if (@mr)
		{
			$self->{requires} = sprintf(";\n\t:requires %s",
				(join ' , ', (map { my ($pkg, $ver) = split /\s+/, $_; ($ver =~ /^v?[0-9\._]+/) ? "\"$pkg $ver\"" : "\"$pkg\"" } @mr))
				);
		}
		else
		{
			$self->{requires} = '';
		}
	}
	
	$self->{pragmas} ||= join "\n", do {
			my @pragmas = grep { /^5\.[0-9_]+$/ } keys %{$self->{use}};
			push @pragmas, '5.010' unless @pragmas;
			push @pragmas, 'autodie' if $self->{use}{autodie};
			push @pragmas, ($self->{use}{boolean}) ?  'boolean' : 'constant { false => 0, true => 1 }';
			push @pragmas, ($self->{use}{common_sense} ? ('common::sense') : ('strict','warnings'));
			push @pragmas, 'utf8';
			push @pragmas, 'Moose' if $self->{use}{moose};
			map { sprintf('use %s;', $_) } @pragmas;
		};
	
	$self->{final_pragmas} ||= join "\n", do {
			my @pragmas;
			push @pragmas, 'namespace::clean' if $self->{use}{namespace_clean} || $self->{use}{moose};
			map { sprintf('use %s;', $_) } @pragmas;
		};

	$self->{final_code} ||= join "\n", do {
			my @lines;
			push @lines, '__PACKAGE__->meta->make_immutable;' if $self->{use}{moose};
			push @lines, 'true;';
			@lines;
		};
		
	foreach (qw(pragmas final_pragmas includes))
	{
		if (ref $self->{$_} eq 'ARRAY')
		{
			$self->{$_} = join "\n", map { "use $_;" } @{ $self->{$_} };
		}
	}
}

sub create_module
{
	my ($self) = @_;
	
	$self->_iofile( $self->{module_filename} )
		->print( $self->_fill_in_template('module') );
}

sub create_makefile_pl
{
	my ($self) = @_;
	
	$self->_iofile('Makefile.PL')
		->print($self->_fill_in_template('Makefile.PL'));
}

sub create_metadata
{
	my ($self) = @_;
	
	$self->_iofile($_)
		->print($self->_fill_in_template($_))
		foreach grep { m#^meta/# } $self->_get_template_names;
}

sub create_tests
{
	my ($self) = @_;
	
	$self->_iofile($_)
		->print($self->_fill_in_template($_))
		foreach grep { m#^t/# } $self->_get_template_names;
}

sub create_author_tests
{
	my ($self) = @_;
	
	$self->_iofile($_)
		->print($self->_fill_in_template($_))
		foreach grep { m#^xt/# } $self->_get_template_names;
}

=head1 NAME

Module::Package::RDF::Create - create distributions that will use Module::Package::RDF.

=head1 SYNOPSIS

  mkdist Local::Example::Useful

=head1 DESCRIPTION

This package provides just one (class) method:

=over

=item C<< Module::Package::RDF::Create->create($distname, %options) >>

Create a distribution directory including all needed files.

=back

There are various methods that may be useful for people subclassing this
class to look at (and possibly override).

=over

=item C<< set_defaults >>

=item C<< create_module >>

=item C<< create_makefile_pl >>

=item C<< create_metadata >>

=item C<< create_tests >>

=item C<< create_author_tests >>

=back

=head1 SEE ALSO

L<Module::Package::RDF>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2011 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

1;

__DATA__

COMMENCE module
package {$module_name};

{$pragmas}

BEGIN \{
	${$module_name}::AUTHORITY = 'cpan:{uc $author->{cpanid}}';
	${$module_name}::VERSION   = '{$version}';
\}

{$includes}
{$final_pragmas}

# Your code goes here

{$final_code}

{}__END__

{}=head1 NAME

{$module_name} - {$abstract}

{}=head1 SYNOPSIS

{}=head1 DESCRIPTION

{}=head1 BUGS

Please report any bugs to
L<http://rt.cpan.org/Dist/Display.html?Queue={URI::Escape::uri_escape($dist_name)}>.

{}=head1 SEE ALSO

{}=head1 AUTHOR

{$author->{name}} E<lt>{$author->{mbox}}E<gt>.

{}=head1 COPYRIGHT AND LICENCE

{$licence->notice}

{}=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

COMMENCE Makefile.PL
use inc::Module::Package 'RDF:standard';

COMMENCE meta/changes.ttl
# This file acts as the project's changelog.

@prefix :        <http://usefulinc.com/ns/doap#> .
@prefix dcs:     <http://ontologi.es/doap-changeset#> .
@prefix dc:      <http://purl.org/dc/terms/> .
@prefix dist:    <http://purl.org/NET/cpan-uri/dist/{URI::Escape::uri_escape($dist_name)}/> .
@prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .

dist:project :release dist:{$version_ident} .
dist:{$version_ident}
	a               :Version ;
	dc:issued       "{DateTime->now->ymd('-')}"^^xsd:date ;
	:revision       "{$version}"^^xsd:string ;
	:file-release   <{$backpan}{URI::Escape::uri_escape($dist_name)}-{$version}.tar.gz> ;
	rdfs:label      "Initial release" .

COMMENCE meta/doap.ttl
# This file contains general metadata about the project.

@prefix :        <http://usefulinc.com/ns/doap#> .
@prefix dc:      <http://purl.org/dc/terms/> .
@prefix foaf:    <http://xmlns.com/foaf/0.1/> .
@prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> .

<http://purl.org/NET/cpan-uri/dist/{URI::Escape::uri_escape($dist_name)}/project>
	a               :Project ;
	:programming-language "Perl" ;
	:name           "{$dist_name}" ;
	:shortdesc      "{$abstract}" ;
	:homepage       <https://metacpan.org/release/{URI::Escape::uri_escape($dist_name)}> ;
	:download-page  <https://metacpan.org/release/{URI::Escape::uri_escape($dist_name)}> ;
	:bug-database   <http://rt.cpan.org/Dist/Display.html?Queue={URI::Escape::uri_escape($dist_name)}> ;
	:created        "{DateTime->now->ymd('-')}"^^xsd:date ;
	:license        <{$licence->url}> ;
	:developer      [ a foaf:Person ; foaf:name "{$author->{name}}" ; foaf:mbox <mailto:{$author->{mbox}}> ] .

<{$licence->url}>
	dc:title        "{$licence->name}" .

COMMENCE meta/makefile.ttl
# This file provides instructions for packaging.

@prefix : <http://purl.org/NET/cpan-uri/terms#> .

<http://purl.org/NET/cpan-uri/dist/{URI::Escape::uri_escape($dist_name)}/project>
	:perl_version_from _:main ;
	:version_from _:main ;
	:readme_from _:main ;
	:test_requires "Test::More 0.61" {$requires} .

_:main <http://www.semanticdesktop.org/ontologies/2007/03/22/nfo#fileName> "{$module_filename}" .

COMMENCE t/01basic.t
use Test::More tests => 1;
BEGIN \{ use_ok('{$module_name}') \};

COMMENCE xt/01pod.t
use Test::More;
eval "use Test::Pod 1.00";
plan skip_all => "Test::Pod 1.00 required for testing POD" if $@;
all_pod_files_ok();

COMMENCE xt/02pod_coverage.t
use Test::More;
use Test::Pod::Coverage;

my @modules = qw({$module_name});
pod_coverage_ok($_, "$_ is covered")
	foreach @modules;
done_testing(scalar @modules);

COMMENCE xt/03meta_uptodate.t
use Test::More tests => 1;
use Test::RDF::DOAP::Version;
doap_version_ok('{$dist_name}', '{$module_name}');

COMMENCE xt/04eol.t
use Test::EOL;
all_perl_files_ok();
