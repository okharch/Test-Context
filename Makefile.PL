use 5.016003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Test::Context',
    VERSION_FROM      => 'lib/Test/Context.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Test/Context.pm', # retrieve abstract from module
       AUTHOR         => 'Oleksandr Kharchenko <kharcheo@ldn.swissbank.com>') : ()),
);
