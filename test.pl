use strict;
use Test;

BEGIN { plan tests => 12 }

ok ( module_loaded("Dimedis::Ddl") );
ok ( module_loaded("Dimedis::Ddl::Constraint") );
ok ( module_loaded("Dimedis::Ddl::Reference") );
ok ( module_loaded("Dimedis::Ddl::Table") );
ok ( module_loaded("Dimedis::Ddl::Index") );
ok ( module_loaded("Dimedis::Ddl::Column") );
ok ( module_loaded("Dimedis::Ddl::Config") );
ok ( module_loaded("Dimedis::Ddl::PrimaryKey") );
ok ( module_loaded("Dimedis::DdlDriver::mysql") );
ok ( module_loaded("Dimedis::DdlDriver::Oracle") );
ok ( module_loaded("Dimedis::DdlDriver::dim_mssql") );
ok ( module_loaded("Dimedis::DdlDriver::Sybase") );

sub module_loaded {
	my ($module) = @_;
	printf ("Loading module %-35s ", $module." ... ");
	eval "use $module";
	return $@ ? 0 : 1;
}
