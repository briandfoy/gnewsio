package GNewsIO::Article;
use parent qw(Hash::AsObject);

sub image_url   ($self) { $self->image        }
sub source_name ($self) { $self->source->name }
sub source_url  ($self) { $self->source->url  }

__PACKAGE__;
