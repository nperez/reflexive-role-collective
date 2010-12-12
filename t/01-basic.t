use warnings;
use strict;
use Test::More;

my $forgets = 0;
my $remembers = 0;

{
    package MyCollection;
    use Moose;
    use Moose::Util::TypeConstraints;
    extends 'Reflex::Base';

    has store => (
        is      => 'rw',
        isa     => 'HashRef',
        traits  => ['Hash'],
        default => sub { {} },
        clearer => 'clear_objects',
        handles => {
            add_object => 'set',
            del_object => 'delete',
            count_objects => 'count',
        },
    );

    with 'Reflexive::Role::Collective' =>
    {
        stored_constraint => role_type('Reflex::Role::Collectible'),
        watched_events => [ [stopped => 'forget_me'] ],
        method_clear_objects => 'clear_objects',
        method_count_objects => 'count_objects',
        method_add_object => 'add_object',
        method_del_object => 'del_object',
    };

    sub forget_me
    {
        my ($self, $args) = @_;
        Test::More::pass('got forget_me. total forgets: ' . ++$forgets);
        $self->forget($args->{_sender});
    }

    around remember => sub
    {
        my ($orig, $self, $obj) = @_;
        Test::More::pass('got remember. total remembers: ' . ++$remembers);
        $self->$orig($obj);
    }
}

{
    package MyCollectible;
    use Moose;
    extends 'Reflex::Base';
    with 'Reflex::Role::Collectible';
}

my $collection = MyCollection->new();
my $collectibles = [];
for(0..9)
{
    push(@$collectibles, MyCollectible->new());
    $collection->remember($collectibles->[$_]);
}

$_->stopped() for @$collectibles;

$collection->run_all();

is($forgets, $remembers, 'got the same amount of forgets and remembers');
is($collection->count_objects, 0, 'No more objects in the collection');
done_testing();
