use strict;
use warnings;
package IPC::Pipeline::Composable::Command;
# ABSTRACT: A command in a pipeline
use English qw( -no_match_vars );
use Data::Dumper;
use autodie;
use POSIX qw(mkfifo O_NONBLOCK O_RDONLY O_WRONLY); # :sys_wait_h
use File::Temp qw(tmpnam);
use IPC::Pipeline::Composable qw( ipc_pipeline );

sub new {
  my ($class,%opt) = @_;
  return bless my $self = { %opt }, $class;
}

sub cmd { shift->{cmd} }
sub args { my ($self) = @_; wantarray ? @{ $self->{args} || [] } : ($self->{args} || []) }

sub spec {
  my ($self, %args) = @_;
  return
    $self->{cmd_str}  ? [ split ' ', $self->{cmd_str} ] :
    $self->{cmd_code} ? $self->{cmd_code} :
    [
      $self->{cmd},
      map {
        if (eval { $_->isa('IPC::Pipeline::Composable::Command') }) {
          my $tf_name = tmpnam();
          mkfifo $tf_name, 0700;
          my $pl = ipc_pipeline($_);
          print Dumper $tf_name, $_, $pl;
          $pl->run( sink_file => $tf_name);
          $_ = $tf_name;
        }
        $_;
      }
      grep { defined }
      map {
        if (eval { $_->isa('IPC::Pipeline::Composable::Placeholder') }) {
          $_ = $args{$_->name} ? $args{$_->name} : undef;
        }
        $_
      } map {my $foo = $_; $foo} @{ $self->{args} || [] }
    ];
}

sub __mk_tmpfifo {
  
}

1 && q{this expression is true};
__END__
