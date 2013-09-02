package Test::Context;

use 5.008;
use strict;
use warnings;

use fields qw(save_mode test_mode save_path digest_class _effective_context _context_checked _checkpoint);
use Test::More;
use IO::File;
use Sereal::Encoder qw(encode_sereal);
use Data::Dumper;

our $VERSION = '0.01';

sub new {
	my $class = shift;
	my $self = {};
	bless $self,$class;
	my %par = @_;
	$self->{$_} = $par{$_} for keys %par;
	$self->{digest_class} = 'Digest::MD5' unless $self->{digest_class};
	my $dc = $self->{digest_class};
	eval "use $dc;1" or die "Unknown digest class $dc";
	my @dc_methods = qw(add hexdigest addfile);
	my  @inv_methods = grep(!$dc->can($_),@dc_methods);
	die "Invalid digest class $dc, methods are not supported: ".join ", ",@inv_methods if @inv_methods;
	return $self if $self->idle;
	$self->load_checkpoints unless $self->{save_mode};
	return $self;        
}

sub idle {
	my $self = shift;
	return !($self->{test_mode} || $self->{save_mode});
}

# continue calculating effective digest for specified context
sub add_context {
	my ($self,$name,$value) = @_;
	return if $self->idle;
	die "can't use this context, it has already been checked:$name" if exists $self->{_context_checked}{$name};
	my $context = $self->{_effective_context}{$name};
	$context = $self->{_effective_context}{$name} = $self->{digest_class}->new unless defined($context);
	$value = encode_sereal($value,{sort_keys=>1}) if ref($value);
	$context->add($value);
}

# check if accumulated (effective) and pattern(source) digest for specified context are equal
sub check_context {
	my ($self,$name,$value) = @_;
	return if $self->idle;
	$self->add_context($name,$value) if defined($value);
	$self->{_context_checked}{$name} = undef; # touch checked flag
	return if $self->{save_mode};
	my $s_digest = $self->{_checkpoint}{$name};
	ok(defined($s_digest),"source digest for context $name found");
	$DB::single = 2;
	my $context = $self->{_effective_context}{$name};
	ok(defined($context),"effective context $name found");
	SKIP: {
		skip "source/target context $name not found", 1 unless defined($s_digest) && defined($context);
		ok($s_digest eq $context->hexdigest,"saved & effective context $name are equal");
	};
}

# completely skip checking for specified context
sub skip_context {
	my ($self,$name,$file) = @_;
	return if $self->idle;
	$self->{_context_checked}{$name} = undef;
	return if $self->{save_mode};
	skip "skip context $name checks", $file?3:2; # skips defined & equal checks and also file exists check
}

# check if file contains the same data as on saved pattern/ save digest of file to patterns
sub check_file {
	my ($self,$file) = @_;
	return if $self->idle;
	my $fh = new IO::File $file, "r";
	ok(defined($fh),"context file $file exists") unless $self->{save_mode};
	my $ctx;
	if (defined($fh)) {
		$ctx = $self->{digest_class}->new;
		$ctx->addfile($fh);
	}
	$self->{_effective_context}{$file} = $ctx;
	$self->check_context($file);
}

sub load_checkpoints {
	my $self = shift;
	my $file = $self->{save_path};
	my $fh = IO::File->new( $file, "r" );
	die "can't open file $file with checkpoints" unless defined $fh;
	while (<$fh>) {
		my ($name,$value) = m{^(\S+)\t(\S+)};
		$self->{_checkpoint}{$name} = $value;
	}
}

sub save_checkpoints {
	my $self = shift;
	return unless $self->{save_mode};
	my $file = $self->{save_path};
	my $fh = IO::File->new( $file, "w" );
	die "can't create file $file with checkpoints: $!" unless defined $fh;
	my @keys = keys %{$self->{_effective_context}};
	for my $name (@keys) {
		die "context was not checked:$name" unless exists $self->{_context_checked}{$name};
		printf $fh "%s\t%s\n",$name,$self->{_effective_context}{$name}->hexdigest;
	}
	close($fh);
}

1;
__END__

=head1 NAME

Test::Context - Save context before refactoring and use it for regression tests

=head1 SYNOPSIS

	use Test::Context;
	my $regression = grep m{^--regression_(save|test)$}, @ARGV;
	my $tc;
	GetOptions (
			"regression_save" => \$regression_save,
			"regression_test" => \$regression_test,
			...
	) || die "$usage\n";
	$tc = Test::Context->new(Test::Context->new(
		save_mode=>$regression_save,
		test_mode=>$regression_test,
		save_path=>"/tmp/script-to-refactor"
	);
  }
  $tc->check_file("/tmp/input"); # when run with --save_context option will store digest of input_file. 
								# with --test_context will check if file exists and digest is the same when it was saved
  $tc->check_context("var1",$var1); # this will check if context "var1" has the very saved digest
  $tc->skip_context("/tmp/input") unless -f "/tmp/input"; # we can proceed without input by saying hello to world
  $tc->save_checkpoints; # call it before exit so --regression_test can use calculated value

=head1 DESCRIPTION

This module helps to organize regression test for module that is refactored.
Refactoring is the process of altering code without altering functionality.
So on the same input the refactored module should produce the identical output.
When run with save_mode flag you save input and output content with add_context..check_context or just check_file.
The first pair can accumulate few values like chain of database update statements and you use check_context on commit.
When run in regression test mode you script check whether it has the same digest values in saved points.
You don't create (leave it undef) Test::Context object to let it run in idle mode (do nothing on method calls).
This is for normal script execution without any regression tests and transparent presence of regression test code in a module.
You don't need to write separate test scripts - just include checking input/ouput context in real script.
It will costs almost nothing and will make great benefits as it clarifies what script does 
(by specifying important context right in the script code) and also by adding the regression 
test functionality to script for a very low cost.

=head1 METHODS
=head2 new
makes
=head2 add_context
This alters effective context.
=head2 check_context
you can check/save context several time. It uses array to saving several contexts with the same name. It then save digests in file comma separated.
=head2 check_file
calculates file digest and save/check it
=head1 SEE ALSO

I tried to find the similar functionality in some CPAN modules.
I will appreciate if you point me on that.

=head1 AUTHOR

Oleksandr Kharchenko, E<lt>okharch@gmail.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Oleksandr Kharchenko

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
