# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Test-Context.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More tests => 16;
use File::Temp qw/ tempfile /;
use Data::Dumper;

BEGIN { use_ok('Test::Context') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

# this will be savepath
my (undef, $tmp_savepath) = tempfile();
#my $tmp_savepath = "/tmp/save_path";
unlink $tmp_savepath;

# create temp file to test check_file
my ($fh, $tmp_file1) = tempfile();
#my $tmp_file1 = "/tmp/file1";my $fh = IO::File->new($tmp_file1,"w");
print $fh rand();
close $fh;

my $class = "Test::Context";
my $tc = $class->new(save_mode=>1,save_path=>$tmp_savepath);
ok($tc->isa($class),"$class->new returned object");

# check whether all public methods supported
my @methods = qw(
check_file
skip_context
check_context
idle
new
);
ok(grep($tc->can($_),@methods) == @methods,"all public methods present");

# create check_points and save them
make_context_check_points();
# destroy $tc to fetch saved checkpoints to savepath
undef $tc;
ok(-s $tmp_savepath,"check points have been saved");
#print "continuing with context checking \n";
# now do regression tests - it should path
$tc = $class->new(save_path=>$tmp_savepath);
ok($tc->isa($class),"$class->new returned object for checking contexts");
ok(exists $tc->{_checkpoint},"checkpoints loaded");
make_context_check_points();

unlink $tmp_savepath, $tmp_file1;

sub make_context_check_points {
	#printf "tc:%s\n",Dumper($tc);
	
	$tc->add_context("1","1");
	$tc->check_context("1");

	$tc->add_context("2","1");
	$tc->add_context("2","2");
	$tc->check_context("2");

	$tc->check_file($tmp_file1);

}
