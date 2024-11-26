use strict;
use warnings;
use IO::Socket;
use IO::Select;
use Time::HiRes qw(time);

my $port = 6000;
my $server = IO::Socket::INET->new(LocalPort => $port, Proto => 'tcp', Listen => 10, Reuse => 1) or die "Erreur: $!\n";
my $selector = IO::Select->new($server);

my %clients;
my %last_activity;
my %rooms;

sub broadcast {
    my ($sender, $message, $room) = @_;
    foreach my $client (values %{$rooms{$room}}) {
        next if $client == $sender;
        print $client "$message";
    }
}

sub send_to {
    my ($socket, $message) = @_;
    print $socket "$message";
}

while (1) {
    my @ready = $selector->can_read(1);
    foreach my $socket (@ready) {
        if ($socket == $server) {
            my $new_client = $server->accept();
            $selector->add($new_client);
            my $id = int(rand(100000));
            $clients{$new_client} = { id => $id, username => "Guest$id", room => 'global' };
            $rooms{global}{$new_client} = $new_client;
            $last_activity{$new_client} = time();
            send_to($new_client, "Bienvenue Guest$id! Tapez /help pour voir les commandes.");
        } else {
            my $data;
            my $bytes_read = $socket->sysread($data, 1024);
            if (defined $bytes_read && $bytes_read > 0) {
                chomp($data);
                my $client_info = $clients{$socket};
                my ($cmd, @args) = split(/\s+/, $data);

                if (defined $cmd && $cmd eq '/quit') {
                    send_to($socket, "Déconnexion...");
                    if (exists $rooms{$client_info->{room}}{$socket}) {
                        delete $rooms{$client_info->{room}}{$socket};
                    }
                    $selector->remove($socket);
                    close $socket;
                    delete $clients{$socket};
                    delete $last_activity{$socket};
                } elsif (defined $cmd && $cmd eq '/username') {
                    $client_info->{username} = join(' ', @args);
                    send_to($socket, "You're username are now $client_info->{username}");
                } elsif (defined $cmd && $cmd eq '/room') {
                    my $room_name = join(' ', @args);
                    if (exists $rooms{$client_info->{room}}{$socket}) {
                        delete $rooms{$client_info->{room}}{$socket};
                    }
                    $client_info->{room} = $room_name;
                    $rooms{$room_name}{$socket} = $socket;
                    send_to($socket, "You are now on the Thread [$room_name]");
                } elsif (defined $cmd && $cmd eq '/msg') {
                    my ($target_id, @msg_parts) = @args;
                    my $message = join(' ', @msg_parts);
                    foreach my $client (keys %clients) {
                        if ($clients{$client}{id} == $target_id) {
                            send_to($client, "[Private $client_info->{username}] $message");
                        }
                    }
                } elsif (defined $cmd && $cmd eq '/list') {
                    my @usernames = map { $clients{$_}{username} } keys %{$rooms{$client_info->{room}}};
                    send_to($socket, "User on the Thread $client_info->{room}" . join(', ', @usernames));
                } elsif (defined $cmd && $cmd eq '/help') {
                    send_to($socket, "/quit - Quit, /username [name] - Change name, /room [name] - Join the Thread, /msg [id] [message] - Private Message, /list - Liste all users.");
                } else {
                    my $formatted_message = "$client_info->{username} - $data";
                    broadcast($socket, $formatted_message, $client_info->{room});
                }
                $last_activity{$socket} = time();
            } else {
                $selector->remove($socket);
                if (exists $clients{$socket}) {
                    my $client_info = $clients{$socket};
                    if (exists $rooms{$client_info->{room}}{$socket}) {
                        delete $rooms{$client_info->{room}}{$socket};
                    }
                    close $socket;
                    delete $clients{$socket};
                    delete $last_activity{$socket};
                }
            }
        }
    }
}
