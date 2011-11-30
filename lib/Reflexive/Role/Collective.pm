package Reflexive::Role::Collective;

#ABSTRACT: Provides a composable behavior for containers watching contained events
use Reflex::Role;
use MooseX::Params::Validate;
use Moose::Util::TypeConstraints;
use MooseX::Types::Moose(':all');
use MooseX::Types::Structured(':all');

=role_parameter collection
    
    default: objects

store contains the name of the attribute that holds the actual collection of
objects.

=cut

attribute_parameter collection => 'objects';

=role_parameter method_add_object

    default: add_object

method_add_object is the name of the method that adds an object to the
collection.

=cut

attribute_parameter method_add_object => 'add_object';

=role_parameter method_del_object

    default: delete_object

method_del_object is the name of the method that deletes objects from the
collection.

=cut

attribute_parameter method_del_object => 'delete_object';

=role_parameter method_count_objects

    default: count_objects

method_count_objects is the name of the method that returns the current count
of objects within the collection.

=cut

attribute_parameter method_count_objects => 'count_objects';

=role_parameter method_clear_objects

    default: clear_objects

method_clear_objects is the name of the method that clears the collection of
any objects.

=cut

attribute_parameter method_clear_objects => 'clear_objects';

=role_parameter method_remember

    default: remember

method_remember is the name of the method that stores the collectible and sets
up watching the events that collectible emits.

=cut

parameter  method_remember =>
(
    isa => Str,
    default => 'remember',
);

=role_parameter method_forget

    default: forget

method_forget is the name of the method that removes the collectible and
ignores any events that the collectible emits.

=cut

parameter  method_forget =>
(
    isa => Str,
    default => 'forget',
);

=role_parameter stored_constraint

    default: Any

stored_constraint stores a Moose::Meta::TypeConstaint object to be used to
constraint collectibles before they are stored into the collection.

=cut


parameter stored_constraint =>
(
    isa => 'Moose::Meta::TypeConstraint',
    default => sub { Any },
);


=role_parameter watched_events

    isa: ArrayRef[Tuple[Str,Str|Tuple[Str,Str]]],

watched_events contains an arrayref of tuples that indicate the event to watch
and the callback method name to call when that event occurs. If the callback
method name is also a tuple, a method will be setup with the name of the first
element of the tuple and it will emit the event in the second element

    # example
    [ some_event => [ 'some_method_that_emits' => 'this_event' ] ]

Internally, the embedded tuple is passed unmodified to
L<Reflex::Role/method_emit>. This allows for easy setup of watched events that
merely re-emit.

=cut

parameter watched_events =>
(
    isa => ArrayRef[Tuple[Str,Str|Tuple[Str,Str]]],
    default => sub { [] },
);

role
{
    my $p = shift;
    use Reflex::Callbacks qw(cb_method);
    
    foreach my $tuple (@{$p->watched_events})
    {
        if(ref($tuple->[1]) eq 'ARRAY')
        {
            my ($method_name, $event_name) = @{$tuple->[1]};
            method $method_name => sub {
                my ($self, $event) = @_;
                $self->re_emit($event, -name => $event_name);
            };
        }
    }

=role_require ignore

This role requires the method ignore from Reflex::Base

=cut

=role_require watch

This role requires the method watch from Reflex::Base

=cut

=role_require clear_objects

This role requires the method named in method_clear_objects

=cut

=role_require count_objects

This role requires the method named in method_count_objects

=cut

=role_require add_object

This role requires the method named in method_add_object

=cut

=role_require delete_object

This role requires the method named in method_del_object

=cut
    requires qw/ignore watch/,
    (
        $p->method_clear_objects,
        $p->method_count_objects,
        $p->method_add_object,
        $p->method_del_object,
    );
    

=method_public remember

remember takes an object constrained by L</store_constraint>. It will then
watch all of the events listed in L</watched_events> and store the object
into the collection

=cut

    method ${\$p->method_remember} => sub
    {
        my ($self, $object) = pos_validated_list
        (
            \@_,
            { does => 'Reflexive::Role::Collective' },
            { isa  => $p->stored_constraint },
        );

        foreach my $tuple (@{$p->watched_events})
        {
            if(ref($tuple->[1]) eq 'ARRAY')
            {
                $self->watch($object, $tuple->[0] => cb_method($self, $tuple->[1]->[0]));
            }
            else
            {
                $self->watch($object, $tuple->[0] => cb_method($self, $tuple->[1]));
            }
        }

        $self->${\$p->method_add_object}($object, $object);
    };

=method_public forget

forget takes an object constrained by L</store_constraint>. It will then
ignore all of the events the collection was watching and the object will be
removed from the collection.

=cut

    method ${\$p->method_forget} => sub
    {
        my ($self, $object) = pos_validated_list
        (
            \@_,
            { does => 'Reflexive::Role::Collective' },
            { isa  => $p->stored_constraint },
        );
        $self->ignore($object);
        $self->${\$p->method_del_object}($object);
    };
};

1;
__END__
=head1 DESCRIPTION

Reflexive::Role::Collective provides are more comprehensive and extensible way
to define collections that act upon events emitted from contained objects.

While Reflex::Collection merely watches for the 'stopped' event and removes it
from the collection, a more sophisticated Collection can be built using this
role that will do much more such as proper socket management, re-emit events,
etc.
