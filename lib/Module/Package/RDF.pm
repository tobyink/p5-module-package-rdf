package Module::Package::RDF;

our $VERSION = '0.001';

package Module::Package::RDF::standard;

use 5.008003;
use strict;

use RDF::Trine 0.133 ();
use Module::Package 0.29 ();
use Module::Install::AutoLicense 0.08 ();
use Module::Install::ReadmeFromPod 0.12 ();
use Module::Install::RDF 0.001 ();
use Module::Install::DOAP 0.001 ();
use Module::Install::DOAPChangeSets 0.103 ();
use Log::Log4perl 0 qw(:easy);

our $VERSION = '0.001';

use Moo;
extends 'Module::Package::Plugin';

sub main
{
	my ($self) = @_;

	$self->mi->rdf_metadata;
	$self->mi->doap_metadata;
	$self->mi->sign;

	# These run later, as specified.
	$self->post_all_from(sub {Log::Log4perl->easy_init($ERROR);$self->mi->write_doap_changes});
	$self->post_all_from(sub {$self->mi->auto_license});
	$self->post_all_from(sub {$self->mi->auto_manifest});
	$self->post_all_from(sub {$self->mi->auto_install});
	
	$self->post_all_from(sub {$self->mi->clean_files('Changes')});
	$self->post_all_from(sub {$self->mi->clean_files('MANIFEST')});
	$self->post_all_from(sub {$self->mi->clean_files('SIGNATURE')});
	$self->post_all_from(sub {$self->mi->clean_files('README')});
	$self->post_all_from(sub {$self->mi->clean_files('LICENSE')});
	$self->post_all_from(sub {$self->mi->clean_files('META.yml')});
}

# We don't want to auto-invoke all_from...
sub all_from
{
	my $self = shift;
	# $self->mi->_all_from(@_);
	$_->() for @{$self->{post_all_from} || []};
}

sub write_deps_list {}

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

=item * RDF

=item * DOAP

=item * DOAPChangeSets

=item * ReadmeFromPod

=item * AutoLicense

=item * AutoManifest

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

=cut
