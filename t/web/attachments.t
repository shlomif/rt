#!/usr/bin/perl -w
use strict;

use RT::Test tests => 134;

use constant LogoFile => $RT::MasonComponentRoot .'/NoAuth/images/bpslogo.png';
use constant FaviconFile => $RT::MasonComponentRoot .'/NoAuth/images/favicon.png';

my ($url, $m) = RT::Test->started_ok;
ok $m->login, 'logged in';

my $queue = RT::Test->load_or_create_queue( Name => 'General' );
ok( $queue && $queue->id, "Loaded General queue" );

diag "test mobile ui";
$m->get_ok( $url . '/m/ticket/create?Queue=' . $queue->id );

$m->form_name('TicketCreate');
$m->field('Subject', 'Attachments test');
$m->field('Attach',  LogoFile);
$m->field('Content', 'Some content');
$m->submit;
is($m->status, 200, "request successful");

$m->content_contains('Attachments test', 'we have subject on the page');
$m->content_contains('bpslogo.png', 'page has file name');

$m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
$m->form_name('TicketUpdate');
$m->field('Attach',  LogoFile);
$m->click('AddMoreAttach');
is($m->status, 200, "request successful");

$m->form_name('TicketUpdate');
$m->field('Attach',  FaviconFile);
$m->field('UpdateContent', 'Message');
$m->click('SubmitTicket');
is($m->status, 200, "request successful");

$m->content_contains('bpslogo.png', 'page has file name');
$m->content_contains('favicon.png', 'page has file name');

diag "create a ticket in full interface";
diag "w/o attachments";
{
    $m->goto_create_ticket( $queue );
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->content_contains("Create a new ticket", 'ticket create page');
    $m->submit;
    is($m->status, 200, "request successful");
}

diag "with one attachment";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Subject', 'Attachments test');
    $m->field('Attach',  LogoFile);
    $m->field('Content', 'Some content');

    $m->submit;
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    $m->content_contains('Download bpslogo.png', 'page has file name');
}

diag "with two attachments";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->field('Subject', 'Attachments test');
    $m->field('Content', 'Some content');

    $m->submit;
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    $m->content_contains('Download bpslogo.png', 'page has file name');
    $m->content_contains('Download favicon.png', 'page has file name');
}

diag "with one attachment, but delete one along the way";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->tick( 'DeleteAttach', LogoFile );
    $m->field('Subject', 'Attachments test');
    $m->field('Content', 'Some content');

    $m->submit;
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    $m->content_lacks('Download bpslogo.png', 'page has file name');
    $m->content_contains('Download favicon.png', 'page has file name');
}

diag "with one attachment, but delete one along the way";
{
    $m->goto_create_ticket( $queue );

    $m->form_name('TicketCreate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->tick( 'DeleteAttach', LogoFile );
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketCreate');
    $m->field('Subject', 'Attachments test');
    $m->field('Content', 'Some content');

    $m->submit;
    is($m->status, 200, "request successful");

    $m->content_contains('Attachments test', 'we have subject on the page');
    $m->content_contains('Some content', 'and content');
    $m->content_lacks('Download bpslogo.png', 'page has file name');
    $m->content_contains('Download favicon.png', 'page has file name');
}

diag "reply to a ticket in full interface";
diag "with one attachment";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
    $m->form_name('TicketUpdate');
    $m->field('Attach',  LogoFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_contains('Download bpslogo.png', 'page has file name');
}

diag "with two attachments";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
    $m->form_name('TicketUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_contains('Download bpslogo.png', 'page has file name');
    $m->content_contains('Download favicon.png', 'page has file name');
}

diag "with one attachment, delete one along the way";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Reply'}, "reply to the ticket");
    $m->form_name('TicketUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketUpdate');
    $m->tick('DeleteAttach',  LogoFile);
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->content_lacks('Download bpslogo.png', 'page has file name');
    $m->content_contains('Download favicon.png', 'page has file name');
}

diag "jumbo interface";
diag "with one attachment";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Jumbo'}, "jumbo the ticket");
    $m->form_name('TicketModifyAll');
    $m->field('Attach',  LogoFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->goto_ticket( $ticket->id );
    $m->content_contains('Download bpslogo.png', 'page has file name');
}

diag "with two attachments";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Jumbo'}, "jumbo the ticket");
    $m->form_name('TicketModifyAll');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketModifyAll');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->goto_ticket( $ticket->id );
    $m->content_contains('Download bpslogo.png', 'page has file name');
    $m->content_contains('Download favicon.png', 'page has file name');
}

diag "with one attachment, delete one along the way";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->goto_ticket( $ticket->id );
    $m->follow_link_ok({text => 'Jumbo'}, "jumbo the ticket");
    $m->form_name('TicketModifyAll');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('TicketModifyAll');
    $m->tick('DeleteAttach',  LogoFile);
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->click('SubmitTicket');
    is($m->status, 200, "request successful");

    $m->goto_ticket( $ticket->id );
    $m->content_lacks('Download bpslogo.png', 'page has file name');
    $m->content_contains('Download favicon.png', 'page has file name');
}

diag "bulk update";
diag "one attachment";
{
    my @tickets = RT::Test->create_tickets(
        {
            Queue   => $queue,
            Subject => 'Attachments test',
            Content => 'Some content',
        },
        {},
        {},
    );
    my $query = join ' OR ', map "id=$_", map $_->id, @tickets;
    $query =~ s/ /%20/g;
    $m->get_ok( $url . "/Search/Bulk.html?Query=$query&Rows=10" );

    $m->form_name('BulkUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->submit;
    is($m->status, 200, "request successful");

    foreach my $ticket ( @tickets ) {
        $m->goto_ticket( $ticket->id );
        $m->content_lacks('Download bpslogo.png', 'page has file name');
        $m->content_contains('Download favicon.png', 'page has file name');
    }
}

diag "two attachments";
{
    my @tickets = RT::Test->create_tickets(
        {
            Queue   => $queue,
            Subject => 'Attachments test',
            Content => 'Some content',
        },
        {},
        {},
    );
    my $query = join ' OR ', map "id=$_", map $_->id, @tickets;
    $query =~ s/ /%20/g;
    $m->get_ok( $url . "/Search/Bulk.html?Query=$query&Rows=10" );

    $m->form_name('BulkUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('BulkUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->submit;
    is($m->status, 200, "request successful");

    foreach my $ticket ( @tickets ) {
        $m->goto_ticket( $ticket->id );
        $m->content_contains('Download bpslogo.png', 'page has file name');
        $m->content_contains('Download favicon.png', 'page has file name');
    }
}

diag "one attachment, delete one along the way";
{
    my @tickets = RT::Test->create_tickets(
        {
            Queue   => $queue,
            Subject => 'Attachments test',
            Content => 'Some content',
        },
        {},
        {},
    );
    my $query = join ' OR ', map "id=$_", map $_->id, @tickets;
    $query =~ s/ /%20/g;
    $m->get_ok( $url . "/Search/Bulk.html?Query=$query&Rows=10" );

    $m->form_name('BulkUpdate');
    $m->field('Attach',  LogoFile);
    $m->click('AddMoreAttach');
    is($m->status, 200, "request successful");

    $m->form_name('BulkUpdate');
    $m->tick('DeleteAttach',  LogoFile);
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    $m->submit;
    is($m->status, 200, "request successful");

    foreach my $ticket ( @tickets ) {
        $m->goto_ticket( $ticket->id );
        $m->content_lacks('Download bpslogo.png', 'page has file name');
        $m->content_contains('Download favicon.png', 'page has file name');
    }
}

diag "self service";
diag "create with attachment";
{
    $m->get_ok( $url . "/SelfService/Create.html?Queue=". $queue->id );

    $m->form_name('TicketCreate');
    $m->field('Attach',  FaviconFile);
    $m->field('Content', 'Message');
    ok(!$m->current_form->find_input('AddMoreAttach'), "one attachment only");
    $m->submit;
    is($m->status, 200, "request successful");

    $m->content_contains('Download favicon.png', 'page has file name');
}

diag "update with attachment";
{
    my $ticket = RT::Test->create_ticket(
        Queue   => $queue,
        Subject => 'Attachments test',
        Content => 'Some content',
    );

    $m->get_ok( $url . "/SelfService/Update.html?id=". $ticket->id );
    $m->form_name('TicketUpdate');
    $m->field('Attach',  FaviconFile);
    $m->field('UpdateContent', 'Message');
    ok(!$m->current_form->find_input('AddMoreAttach'), "one attachment only");
    $m->submit;
    is($m->status, 200, "request successful");

    $m->content_contains('Download favicon.png', 'page has file name');
}
