use strict;

package Dimedis::Ddl::PrimaryKey::dim_mssql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::PrimaryKey );

sub get_ddl {
	my $self = shift;

	return 	"CONSTRAINT ".
		$self->get_name." ".
		"PRIMARY KEY (".$self->get_on.")";
}

sub get_create_ddl {
	my $self = shift;
	
	my $table = $self->get_table->get_name;
	
	return 	"ALTER TABLE $table ADD ".
		" CONSTRAINT ".$self->get_name.
		" PRIMARY KEY(".$self->get_on.")";
}

sub get_drop_ddl {
	my $self = shift;

	return  "ALTER TABLE ".$self->get_table->get_name.
		" DROP CONSTRAINT ".$self->get_name;
}

package Dimedis::Ddl::Table::dim_mssql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Table );

sub get_create_ddl {
	my $self = shift;

	my $sql = $self->SUPER::get_create_ddl;

	$sql .= " ".$self->get_db_specific->{table}
		 if $self->get_db_specific->{table};
	
	return $sql;
}

package Dimedis::Ddl::Column::dim_mssql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Column );

sub get_ddl {
	my $self = shift;
	
	my $tmp;
	my $type = $self->get_type;
	my $full_type = $self->get_full_type;

	my $sql = sprintf ("%-18s  ", $self->get_name);

	if ( $type eq 'serial' ) {
		$sql .= "INTEGER ";

	} elsif ( $type eq 'native_date' ) {
		$sql .= "DATETIME ";

	} elsif ( $type eq 'blob' or $type eq 'clob' ) {
		$sql .= "INTEGER ";

	} elsif ( $full_type =~ /numeric/i ) {
		$full_type =~ s/numeric\s*\(\s*(\d+)\s*\)/NUMERIC($1,0)/i;
		$sql .= "$full_type ";

	} else {
		$sql .= "$full_type ";
	}

	if ( defined $self->get_default ) {
		$tmp = $self->get_default;
		$tmp =~ s/SYSDATE/getdate()/i;
		$sql .= "DEFAULT $tmp ";
	}
	
	if ( $self->get_not_null ) {
		$sql .= "NOT NULL ";
	}

	if ( $self->get_null ) {
		$sql .= "NULL ";
	}
	
	$sql =~ s/\s+$//;

	return $sql;
}

sub get_alter_modify_ddl {
	my $self = shift;
	
	my $sql = "ALTER TABLE ".$self->get_table->get_name.
	          " ALTER COLUMN ".$self->get_ddl;

	$sql =~ s/\s+/ /g;
	
	return $sql;
}

package Dimedis::Ddl::Index::dim_mssql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Index );

sub get_drop_ddl {
      my $self = shift;
      
      return  "DROP INDEX ".$self->get_table->get_name.".".$self->get_name;
}

package Dimedis::Ddl::Constraint::dim_mssql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Constraint );

sub get_create_ddl {
	my $self = shift;
	
	my $table = $self->get_table->get_name;
	
	if ( $self->get_unique ) {
		return  "ALTER TABLE ".$self->get_table->get_name.
			" ADD CONSTRAINT ".$self->get_name.
			" UNIQUE (".$self->get_unique.")"
	} else {
		return 	"ALTER TABLE $table ADD ".
			"CONSTRAINT ".$self->get_name.
			" CHECK(".$self->get_expr.")";
	}
}

sub get_drop_ddl {
	my $self = shift;

	return  "ALTER TABLE ".$self->get_table->get_name.
		" DROP CONSTRAINT ".$self->get_name;
}

package Dimedis::Ddl::Reference::dim_mssql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Reference );

sub get_create_ddl {
	my $self = shift;
	
	my $table = $self->get_table->get_name;
	
	my $delete_cascade = lc($self->get_delete_cascade);
	
	return 	"ALTER TABLE $table ADD ".
		"CONSTRAINT ".$self->get_name." ".
		"FOREIGN KEY (".$self->get_src_col.") ".
		"REFERENCES ".$self->get_dest_table.
		"(".$self->get_dest_col.")".
		(($delete_cascade and
		  $delete_cascade ne 'cyclic') ?
		 " ON DELETE CASCADE" : "" );
}

sub get_drop_ddl {
	my $self = shift;

	return  "ALTER TABLE ".$self->get_table->get_name.
		" DROP CONSTRAINT ".$self->get_name;
}

1;
