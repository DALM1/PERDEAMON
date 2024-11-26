use strict;
use warnings;
use IO::Socket;
use Term::ANSIColor;
use Term::ReadLine;
use POSIX qw(strftime);
use Term::ReadKey;

my $host = '127.0.0.1';
my $port = 6000;

my $socket = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp') or die "Erreur: $!\n";

my $term = Term::ReadLine->new('Chat Client');
my $pid = fork();

my ($width) = GetTerminalSize();

sub format_message {
    my ($message) = @_;
    my $time = strftime("%H:%M:%S", localtime);
    return colored("[\033[1;32m$time\033[0m] $message", 'bold');
}

sub wrap_text {
    my ($text, $line_width) = @_;
    my @lines;
    while (length($text) > $line_width) {
        push @lines, substr($text, 0, $line_width, '');
    }
    push @lines, $text if $text ne '';
    return @lines;
}

sub display_message {
    my ($message) = @_;
    my @wrapped = wrap_text($message, $width - 2);
    foreach my $line (@wrapped) {
        print "$line\n";
    }
}

if ($pid == 0) {
    while (1) {
        my $response;
        my $bytes_read = $socket->sysread($response, 1024);
        if (defined $bytes_read && $bytes_read > 0) {
            chomp($response);
            print "\r";
            display_message(format_message($response));
            print "> ";
        } elsif (defined $bytes_read && $bytes_read == 0) {
            print "\n", colored("Le serveur a fermé la connexion.", 'red bold'), "\n";
            exit(0);
        }
    }
} else {
    while (1) {
        my $input = $term->readline('> ');
        if ($input eq '/quit') {
            $socket->syswrite("$input\n");
            kill 'TERM', $pid;
            last;
        }
        $socket->syswrite("$input\n");
    }
}
