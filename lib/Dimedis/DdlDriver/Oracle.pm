use strict;

package Dimedis::Ddl::PrimaryKey::Oracle;
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
	
	return "ALTER TABLE ".$self->get_table->get_name.
		" ADD CONSTRAINT ".$self->get_name.
		" PRIMARY KEY(".$self->get_on.")";
}

sub get_drop_ddl {
	my $self = shift;

	return  "ALTER TABLE ".$self->get_table->get_name.
		" DROP CONSTRAINT ".$self->get_name;
}

package Dimedis::Ddl::Table::Oracle;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Table );

sub get_oracle_seq_name {
	my $self = shift;

	return "" if not $self->get_ddl_object
			      ->get_hint('create_oracle_sequence');

	return $self->get_name."_SEQ";
}


sub get_create_ddl {
	my $self = shift;

	my $sql = $self->SUPER::get_create_ddl;

	$sql .= " ".$self->get_db_specific->{table}
		 if $self->get_db_specific->{table};
	
	my $seq_name = $self->get_oracle_seq_name;
	
	if ( $seq_name ) {
		my $seq_sql =
			"CREATE SEQUENCE $seq_name ".
			"START WITH 1 INCREMENT BY 1";
		return ($sql, $seq_sql);
	} else {
		return $sql;
	}
}

sub get_drop_ddl {
	my $self = shift;

	my @sql = $self->SUPER::get_drop_ddl;
	
	my $seq_name = $self->get_oracle_seq_name;
	
	push @sql, "DROP SEQUENCE $seq_name" if $seq_name;

	return @sql;
}

package Dimedis::Ddl::Column::Oracle;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Column );

sub get_ddl {
	my $self = shift;
	
	my $tmp;
	my $type = $self->get_type;
	my $sql = sprintf ("%-18s  ", $self->get_name);

	if ( $type eq 'varchar' ) {
		$tmp = $self->get_full_type;
		$tmp =~ s/VARCHAR/VARCHAR2/i;
		$sql .= "$tmp ";

	} elsif ( $type eq 'serial' ) {
		$sql .= "INTEGER ";

	} elsif ( $type eq 'native_date' ) {
		$sql .= "DATE ";

	} else {
		$sql .= $self->get_full_type." ";
	}

	if ( defined $self->get_default ) {
		$sql .= "DEFAULT ".$self->get_default." ";
	}
	
	if ( $self->get_not_null and
	     ( $self->get_alter_state eq 'create' or
	       $self->get_null_alter ) ) {
		$sql .= "NOT NULL ";
	}

	if ( $self->get_null and
	     ( $self->get_alter_state eq 'create' or
	       $self->get_null_alter ) ) {
		$sql .= "NULL ";
	}
	
	$sql =~ s/\s+$//;

	return $sql;
}

package Dimedis::Ddl::Index::Oracle;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Index );

package Dimedis::Ddl::Constraint::Oracle;
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

package Dimedis::Ddl::Reference::Oracle;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Reference );

sub get_create_ddl {
	my $self = shift;
	
	my $table = $self->get_table->get_name;
	
	return 	"ALTER TABLE $table ADD ".
		"CONSTRAINT ".$self->get_name." ".
		"FOREIGN KEY (".$self->get_src_col.") ".
		"REFERENCES ".$self->get_dest_table.
		"(".$self->get_dest_col.")".
		($self->get_delete_cascade ?
		 " ON DELETE CASCADE" : "" );
}

sub get_drop_ddl {
	my $self = shift;

	return  "ALTER TABLE ".$self->get_table->get_name.
		" DROP CONSTRAINT ".$self->get_name;
}


1;
