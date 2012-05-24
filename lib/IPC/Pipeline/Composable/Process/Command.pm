use strict;
use warnings;
package IPC::Pipeline::Composable::Process::Command;
# ABSTRACT: A system command to be run in a separate process
use English qw(-no_match_vars);
use Carp;
#use File::Slurp qw(read_file write_file);
#use List::Util qw(first max maxstr min minstr reduce shuffle sum);
#use Scalar::Util qw(blessed reftype openhandle);
use Params::Util qw(_STRING _ARRAYLIKE _HASHLIKE);

use parent qw(IPC::Pipeline::Composable::Process Exporter);

our @EXPORT_OK = qw(ipc_newcmd ipc_cmd);

sub run {
  my ($self, %opt) = @_;

  # store process subst fifo => process specs here
  my %ps_fifo = %{ $opt{ps_fifo} || {} };

  my @real_args = _process_args($self->{args}, \%opt, \%ps_fifo);

  return _really_run();
}

sub _process_args {
  my ($args, $opt, $ps_fifo) = @_;

  my @real_args;
  for my $arg ( @$args} ) {

    # process substitution
    if ( _is_ps_spec($arg) ) {
      # make the fifo, record the association to its command, and push
      # it onto the command's real args
      my $fifo_name = tmpnam(); # race condition? probably.
      mkfifo $fifo_name, 0700;
      $ps_fifo->{$fifo_name} = $arg;
      push @real_args, $fifo_name;
      next;
    }

    # command substitution
    if ( _is_cs_spec($arg) ) {
      # run the pipeline of commands, collect stdout into buffer,
      # push buffer contents onto real args
      my $buf;
      ipc_pl(@$arg)->run(stdout => \$buf, ps_fifo => $ps_fifo)->finish;
      push @real_args, $buf;
      next;
    }

    # placeholder
    if ( _is_ph_spec($arg) ) {
      # blargh
      $ph_name = $arg->[0];
    }

    # normal argument
    if ( _STRING($arg) ) {
      push @real_args, $arg;
      next;
    }

    # allow this so we have a mechanism to *skip* arguments
    next if !defined $arg;

    croak "Unknown type of command argument: [$arg]";
  }

  return @real_args;
}

# we know it's a process-substitution spec if it's an array where the first
# element is a string indicating the PS mode, and the remaining elements
# are all arrays or hashes. (the arrays are commands and the hashes are
# options)
sub _is_ps_spec {
  my ($spec) = @_;
  return unless _ARRAYLIKE($spec);
  return unless $spec->[0] =~ /^[<>]$/;
  # we want the inverse - if any elements match the grep, the spec isn't correct.
  return ! grep { ! _ARRAYLIKE($_) and ! _HASHLIKE($_) } @$spec[ 1 .. $#$spec ];
}

# we know it's a command-substitution spec if it's an array where all
# elements are either arrays or hashes. (the arrays are commands and
# the hashes are options)
sub _is_cs_spec {
  my ($spec) = @_;
  return unless _ARRAYLIKE($spec);
  return ! grep { ! _ARRAYLIKE($_) and ! _HASHLIKE($_) } @$spec;
}

# we know it's a placeholder spec if it's an array with a single element
# that is a string.
sub _is_ph_spec {
  my ($spec) = @_;
  return unless _ARRAYLIKE($spec);
  return unless @$spec == 1;
  return defined _STRING($spec->[0]);
}

sub new {
  my ($class, %opt) = @_;

  my $self = $class->SUPER::new(%opt);

  croak "the cmd parameter is required!\n" unless $opt{cmd};
  croak "the cmd parameter must be a string!\n" unless defined _STRING($opt{cmd});

  return bless $self, $class;
}


1 && q{this statement is true};
__END__
