use v5.36;

package GNewsIO::Results;
use parent qw(Hash::AsObject);

sub is_error       ($self) { 0 }
sub is_success     ($self) { 1 }

sub is_free_plan   ($self) {
	eval {
		$self->information->{'realTimeArticles'}{'message'} =~ m/only available on paid plans/
		} // 0
	}

sub total_articles ($self) { $self->{'totalArticles'} }
sub information    ($self) { $self->{'information'}   }
sub articles       ($self) { $self->{'articles'}      }

__PACKAGE__;
