#!/usr/bin/perl -w
use strict;

use Test::More tests => 26;
use RT::Test;
my ($baseurl, $m) = RT::Test->started_ok;

use constant ImageFile => $RT::MasonComponentRoot .'/NoAuth/images/bplogo.gif';
use constant ImageFileContent => do {
    local $/;
    open my $fh, '<:raw', ImageFile or die $!;
    scalar <$fh>;
};

ok $m->login, 'logged in';

diag "Create a CF" if $ENV{'TEST_VERBOSE'};
{
    $m->follow_link( text => 'Configuration' );
    $m->title_is(q/RT Administration/, 'admin screen');
    $m->follow_link( text => 'Custom Fields' );
    $m->title_is(q/Select a Custom Field/, 'admin-cf screen');
    $m->follow_link( text => 'New custom field' );
    $m->submit_form(
        form_name => "ModifyCustomField",
        fields => {
            TypeComposite => 'Image-0',
            LookupType => 'RT::Model::Queue-RT::Model::Ticket',
            Name => 'img',
            Description => 'img',
        },
    );
}

diag "apply the CF to General queue" if $ENV{'TEST_VERBOSE'};
my $cfid;
{
    $m->title_is(q/Created CustomField img/, 'admin-cf Created');
    $m->follow_link( text => 'Queues' );
    $m->title_is(q/Admin queues/, 'admin-queues screen');
    $m->follow_link( text => 'General' );
    $m->title_is(q/Editing Configuration for queue General/, 'admin-queue: general');
    $m->follow_link( text => 'Ticket Custom Fields' );

    $m->title_is(q/Edit Custom Fields for General/, 'admin-queue: general cfid');
    $m->form_name('EditCustomFields');

    # Sort by numeric IDs in names
    my @names = map  { $_->[1] }
                sort { $a->[0] <=> $b->[0] }
                map  { /Object-1-CF-(\d+)/ ? [ $1 => $_ ] : () }
                grep defined, map $_->name, $m->current_form->inputs;
    $cfid = pop(@names);
    $cfid =~ /(\d+)$/ or die "Hey this is impossible dude";
    $m->field( $cfid => 1 );         # Associate the new CF with this queue
    $m->field( $_ => undef ) for @names;    # ...and not any other. ;-)
    $m->submit;

    $m->content_like( qr/Object Created/, 'TCF added to the queue' );
}

my $tester = RT::Test->load_or_create_user( Name => 'tester', Password => '123456' );
RT::Test->set_rights(
    { Principal => $tester->PrincipalObj,
      Right => [qw(SeeQueue ShowTicket CreateTicket)],
    },
);
ok $m->login( $tester->Name, 123456), 'logged in';

diag "check that we have no the CF on the create"
    ." ticket page when user has no SeeCustomField right"
        if $ENV{'TEST_VERBOSE'};
{
    $m->submit_form(
        form_name => "CreateTicket_in_queue",
        fields => { Queue => 'General' },
    );
    $m->content_unlike(qr/Upload multiple images/, 'has no upload image field');

    my $form = $m->form_name("TicketCreate");
    my $upload_field = "Object-RT::Model::Ticket--CustomField-$1-Upload";
    ok !$form->find_input( $upload_field ), 'no form field on the page';

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
    );
    $m->content_like(qr/Ticket \d+ Created/, "a ticket is Created succesfully");

    $m->content_unlike(qr/img:/, 'has no img field on the page');
    $m->follow_link( text => 'Custom Fields');
    $m->content_unlike(qr/Upload multiple images/, 'has no upload image field');
}

RT::Test->set_rights(
    { Principal => $tester->PrincipalObj,
      Right => [qw(SeeQueue ShowTicket CreateTicket SeeCustomField)],
    },
);

diag "check that we have no the CF on the create"
    ." ticket page when user has no ModifyCustomField right"
        if $ENV{'TEST_VERBOSE'};
{
    $m->submit_form(
        form_name => "CreateTicket_in_queue",
        fields => { Queue => 'General' },
    );
    $m->content_unlike(qr/Upload multiple images/, 'has no upload image field');

    my $form = $m->form_name("TicketCreate");
    my $upload_field = "Object-RT::Model::Ticket--CustomField-$1-Upload";
    ok !$form->find_input( $upload_field ), 'no form field on the page';

    $m->submit_form(
        form_name => "TicketCreate",
        fields => { Subject => 'test' },
    );
    my $tid = $1 if $m->content =~ /Ticket (\d+) Created/i;
    ok $tid, "a ticket is Created succesfully";

    $m->follow_link( text => 'Custom Fields' );
    $m->content_unlike(qr/Upload multiple images/, 'has no upload image field');
    $form = $m->form_number(3);
    $upload_field = "Object-RT::Model::Ticket-$tid-CustomField-$cfid-Upload";
    ok !$form->find_input( $upload_field ), 'no form field on the page';
}

RT::Test->set_rights(
    { Principal => $tester->PrincipalObj,
      Right => [qw(SeeQueue ShowTicket CreateTicket SeeCustomField ModifyCustomField)],
    },
);

diag "create a ticket with an image" if $ENV{'TEST_VERBOSE'};
my $tid;
{
    $m->submit_form(
        form_name => "CreateTicket_in_queue",
        fields => { Queue => 'General' },
    );
    $m->content_like(qr/Upload multiple images/, 'has a upload image field');

    $cfid =~ /(\d+)$/ or die "Hey this is impossible dude";
    my $upload_field = "Object-RT::Model::Ticket--CustomField-$1-Upload";

    $m->submit_form(
        form_name => "TicketCreate",
        fields => {
            $upload_field => ImageFile,
            Subject => 'testing img cf creation',
        },
    );

    $m->content_like(qr/Ticket \d+ Created/, "a ticket is Created succesfully");

    $tid = $1 if $m->content =~ /Ticket (\d+) Created/;

    $m->title_like(qr/testing img cf creation/, "its title is the Subject");

    $m->follow_link( text => 'bplogo.gif' );
    $m->content_is(ImageFileContent, "it links to the uploaded image");
}

$m->get( $m->rt_base_url );
$m->follow_link( text => 'Tickets' );
$m->follow_link( text => 'New Query' );

$m->title_is(q/Query Builder/, 'Query building');
$m->submit_form(
    form_name => "BuildQuery",
    fields => {
        idOp => '=',
        ValueOfid => $tid,
        ValueOfQueue => 'General',
    },
    button => 'AddClause',
);

$m->form_name('BuildQuery');

my $col = ($m->current_form->find_input('SelectDisplayColumns'))[-1];
$col->value( ($col->possible_values)[-1] );

$m->click('AddCol');

$m->form_name('BuildQuery');
$m->click('DoSearch');

$m->follow_link( text_regex => qr/bplogo\.gif/ );
$m->content_is(ImageFileContent, "it links to the uploaded image");

__END__
[FC] Bulk Update does not have custom fields.
