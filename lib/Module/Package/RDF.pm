package Module::Package::RDF;

use 5.008003;
BEGIN {
	$Module::Package::RDF::AUTHORITY = 'cpan:TOBYINK';
	$Module::Package::RDF::VERSION   = '0.005';
}

package Module::Package::RDF::standard;

use 5.008003;
use strict;

use RDF::Trine 0.133 ();
use Module::Package 0.30 ();
use Module::Install::AutoInstall 0 ();
use Module::Install::AutoLicense 0.08 ();
use Module::Install::AutoManifest 0 ();
use Module::Install::ReadmeFromPod 0.12 ();
use Module::Install::RDF 0.002 ();
use Module::Install::DOAP 0.002 ();
use Module::Install::DOAPChangeSets 0.201 ();
use Module::Install::TrustMetaYml 0.001 ();
use Log::Log4perl 0 qw(:easy);

BEGIN {
        $Module::Package::RDF::standard::AUTHORITY = 'cpan:TOBYINK';
        $Module::Package::RDF::standard::VERSION   = '0.005';
}

use Moo;
extends 'Module::Package::Plugin';

sub main
{
	my ($self) = @_;

	$self->mi->trust_meta_yml;
	$self->mi->rdf_metadata;
	$self->mi->doap_metadata;
	$self->mi->sign;
	
	$self->mi->include_deps('Module::Package::Dist::RDF');

	# These run later, as specified.
	$self->post_all_from(sub {Log::Log4perl->easy_init($ERROR);$self->mi->write_doap_changes});
	$self->post_all_from(sub {$self->mi->auto_license});
	$self->post_all_from(sub {$self->mi->auto_manifest});
	$self->post_all_from(sub {$self->mi->auto_install});
	
	$self->post_all_from(sub {$self->mi->clean_files('Changes')});
	$self->post_all_from(sub {$self->mi->clean_files('inc')});
	$self->post_all_from(sub {$self->mi->clean_files('LICENSE')});
	$self->post_all_from(sub {$self->mi->clean_files('MANIFEST')});
	$self->post_all_from(sub {$self->mi->clean_files('META.yml')});
	$self->post_all_from(sub {$self->mi->clean_files('MYMETA.json')});
	$self->post_all_from(sub {$self->mi->clean_files('MYMETA.yml')});
	$self->post_all_from(sub {$self->mi->clean_files('README')});
	$self->post_all_from(sub {$self->mi->clean_files('SIGNATURE')});
}

# We don't want to auto-invoke all_from...
sub all_from
{
	my $self = shift;
	# $self->mi->_all_from(@_);
	$_->() for @{$self->{post_all_from} || []};
}

sub write_deps_list {}

__END__

=head1 NAME

Module::Package::RDF - drive your distribution with RDF

=head1 SYNOPSIS

In your Makefile.PL:

  use inc::Module::Package 'RDF:standard';

That's all folks!

=head1 DESCRIPTION

Really simple Makefile.PL.

=head1 FLAVOURS

Currently this module only defines the C<:standard> flavour.

=head2 :standard

In addition to the inherited behavior, this flavour uses the following plugins:

=over

=item * AutoLicense

=item * AutoManifest

=item * DOAP

=item * DOAPChangeSets

=item * RDF

=item * ReadmeFromPod

=item * TrustMetaYml

=back

=head1 BUGS

Please report any bugs to L<http://rt.cpan.org/>.

=head1 SEE ALSO

L<Module::Package>,
L<Module::Install::RDF>,
L<Module::Install::DOAP>,
L<Module::Install::DOAPChangeSets> .

L<http://www.perlrdf.org/>.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Toby Inkster

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut
