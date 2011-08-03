use strict;
use warnings;

use RT::Test tests => 15;

my $ticket = RT::Test->create_ticket(
    Subject => 'test bulk update',
    Queue   => 1,
);

my ( $url, $m ) = RT::Test->started_ok;
ok( $m->login, 'logged in' );

$m->get_ok( $url . "/Ticket/ModifyAll.html?id=" . $ticket->id );

$m->submit_form(
    form_number => 3,
    fields      => { 'UpdateContent' => 'this is update content' },
    button      => 'SubmitTicket',
);

$m->content_contains("Message recorded", 'updated ticket');
$m->content_lacks("this is update content", 'textarea is clear');

$m->get_ok($url . '/Ticket/Display.html?id=' . $ticket->id );
$m->content_contains("this is update content", 'updated content in display page');

# Failing test where the time units are not preserved when you
# click 'Add more files' on Display
for (qw/Estimated Worked Left/) {
    $m->goto_create_ticket(1);
    $m->form_name('TicketCreate');
    $m->select("Time${_}-TimeUnits" => 'hours');
    $m->click('AddMoreAttach');
    $m->form_name('TicketCreate');
    is ($m->value("Time${_}-TimeUnits"), 'hours', 'time units stayed to "hours" after the page was refreshed');
}
