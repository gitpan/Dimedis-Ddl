# $Id: Makefile.PL,v 1.2 2003/06/02 10:28:38 joern Exp $

use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'	=> 'Dimedis::Ddl',
    'VERSION_FROM' => 'lib/Dimedis/Ddl.pm',
    'EXE_FILES' => [ 'bin/dddl','bin/dddl_create_config', 'bin/dddl_create_pk',
    		     'bin/dddl_save_trigger' ],
    'dist' => {
        COMPRESS => "gzip",
        SUFFIX => "gz",
        POSTOP   => "test -d dist || mkdir dist; mv *.tar.gz dist",
    }
);
