use strict;

package Dimedis::Ddl::PrimaryKey::mysql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::PrimaryKey );

sub get_ddl {
	my $self = shift;

	my $schema = $self->get_ddl_object->get_driver_object->get_schema_object;
	
	$schema->get_index_by_key
	       ->{$self->get_table->get_name}
	       ->{$self->get_on} = $self->get_name;

	return 	"PRIMARY KEY (".$self->get_on.")";
}

sub get_create_ddl {
	my $self = shift;
	
	my $schema = $self->get_ddl_object->get_driver_object->get_schema_object;
	
	$schema->get_index_by_key
	       ->{$self->get_table->get_name}
	       ->{$self->get_on} = $self->get_name;

	return  "ALTER TABLE ".$self->get_table->get_name.
		" ADD PRIMARY KEY (".$self->get_on.")";
}

sub get_drop_ddl {
	my $self = shift;
	
	my $schema = $self->get_ddl_object->get_driver_object->get_schema_object;
	
	delete $schema->get_index_by_key
		      ->{$self->get_table->get_name}
		      ->{$self->get_on};

	return  "ALTER TABLE ".$self->get_table->get_name.
		" DROP PRIMARY KEY";
}

package Dimedis::Ddl::Table::mysql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Table );

sub get_create_ddl {
	my $self = shift;

	my $sql = $self->SUPER::get_create_ddl(@_);
	
	$sql .= " type=InnoDB";
	
	return $sql;
}


sub get_drop_ddl {
	my $self = shift;
	
	my $schema = $self->get_ddl_object
			  ->get_driver_object
			  ->get_schema_object;

	delete $schema->get_index_by_key
		      ->{$self->get_name};

	return $self->SUPER::get_drop_ddl(@_);
}


package Dimedis::Ddl::Column::mysql;

use vars qw ( @ISA );

@ISA = qw ( Dimedis::Ddl::Column );

sub get_ddl {
	my $self = shift;

	my $name       = $self->get_name;
	my $type       = $self->get_type;
	my $full_type  = $self->get_full_type;
	my $table_name = $self->get_table->get_name;
	
	my $not_null = $self->get_not_null;
	my $null     = $self->get_null;
	my $default  = $self->get_default;

	my $tmp;
	my $sql = sprintf ("%-18s  ", $self->get_name);

	if ( $type eq 'varchar' ) {
		$full_type =~ /\((\d+)\)/;
		if ( $1 > 255 ) {
			if ( $self->get_case_sensitive ) {
				$full_type = "MEDIUMBLOB";
			} else {
				$full_type = "MEDIUMTEXT";
			}
		} else {
			if ( $self->get_case_sensitive ) {
				$full_type .= " BINARY";
			}
		}
	}

	if ( $type eq 'serial' ) {
		$full_type = "INTEGER NOT NULL AUTO_INCREMENT";

	} elsif ( $self->get_table->get_primary_key eq $name ) {
		$not_null = 1;
	}

	if ( $type eq 'native_date' ) {
		$full_type = "DATE";
	}

	if ( $full_type =~ /numeric/i ) {
		$full_type =~ s/numeric\s*\(\s*(\d+)\s*\)/NUMERIC($1,0)/i;
	}

	if ( $type eq 'clob' ) {
		$full_type = "LONGTEXT";
	}

	if ( $type eq 'blob' ) {
		$full_type = "LONGBLOB";
	}

	$sql .= "$full_type ";

	if ( $default ne '' and $default !~ /sysdate/i ) {
		$default =~ s/[()]//g;
		$sql .= "DEFAULT $default ";
	}
	
	if ( $not_null and not $type eq 'serial' ) {
		$sql .= "NOT NULL ";
	}
	
	if ( $null ) {
		$sql .= "NULL ";
	}
	
	$sql =~ s/\s+$//;

	return $sql;
}

package Dimedis::Ddl::Index::mysql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Index );

sub get_create_ddl {
	my $self = shift;
	
	$self->get_ddl_object
	     ->get_driver_object
	     ->get_schema_object
	     ->add_index ( index => $self );

	return $self->SUPER::get_create_ddl (@_); 
}

sub get_drop_ddl {
	my $self = shift;
	
	$self->get_ddl_object
	     ->get_driver_object
	     ->get_schema_object
	     ->drop_index ( index => $self );
	
	return  "DROP INDEX ".$self->get_name.
		" ON ".$self->get_table->get_name;
}

package Dimedis::Ddl::Constraint::mysql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Constraint );

sub get_create_ddl {
	my $self = shift;
	
	my $table = $self->get_table->get_name;
	
	if ( $self->get_unique ) {

		$self->get_ddl_object
		     ->get_driver_object
		     ->get_schema_object
		     ->add_index ( constraint => $self );

		return 	"CREATE UNIQUE".
			" INDEX ".$self->get_name.
			" ON ".$self->get_table->get_name.
			"(".$self->get_unique.")";
	} else {
		return;
	}
}

sub get_drop_ddl {
	my $self = shift;
	
	if ( $self->get_unique ) {
		$self->get_ddl_object
		     ->get_driver_object
		     ->get_schema_object
		     ->drop_index ( constraint => $self );

		return  "DROP INDEX ".$self->get_name." ON ".
			$self->get_table->get_name;
	} else {
		return;
	}
}

package Dimedis::Ddl::Reference::mysql;
use vars qw ( @ISA );
@ISA = qw ( Dimedis::Ddl::Reference );

sub get_create_ddl {
	my $self = shift;

	$self->get_ddl_object->add_error (
		table   => $self->get_table->get_name,
		column  => $self->get_src_col,
		message => "CREATE REFERENCE needs a DBI handle",
	), return if not $self->get_ddl_object->get_dbh;

	my @sql;

	my $schema = $self->get_ddl_object->get_driver_object->get_schema_object;

	# Ggf. Index auf lokale Spalten legen
	# ($dont enthält dann Kommentarzeichen, wenn Index schon da)

	my ($dont, $exists_name);

	if ( $exists_name=
		$schema->get_index_by_key
		       ->{$self->get_table->get_name}
		       ->{$self->get_src_col} ) {
		$dont = "# INDEX EXISTS ($exists_name): ";
	} else {
		$schema->add_index (
			reference    => $self,
			ref_idx_type => "src",
		);
	}

	push @sql,
		"${dont}CREATE INDEX d3l_".$self->get_name." ON ".
		$self->get_table->get_name."(".
		$self->get_src_col.")";

	# Ggf. Index auf entfernte Spalten legen
	# ($dont enthält dann Kommentarzeichen, wenn Index schon da)
	($dont, $exists_name) = ("","");

	if ( $exists_name=
		 $schema->get_index_by_key
			->{$self->get_dest_table}
			->{$self->get_dest_col} ) {
		$dont = "# INDEX EXISTS ($exists_name): ";
	} else {
		$schema->add_index (
			reference    => $self,
			ref_idx_type => "dest",
		);
	}

	push @sql,
		"${dont}CREATE INDEX d3l_".$self->get_name."_dest ON ".
		$self->get_dest_table."(".
		$self->get_dest_col.")";

	#-- eigentlichen Constraint anlegen
	push @sql,
		"ALTER TABLE ".$self->get_table->get_name.
		" ADD CONSTRAINT FOREIGN KEY (".
		$self->get_src_col.") REFERENCES ".$self->get_dest_table.
		"(".$self->get_dest_col.")".
		($self->get_delete_cascade ? " ON DELETE CASCADE" : "" );
	
	return @sql;
}

sub get_drop_ddl {
	my $self = shift;

	$self->get_ddl_object->add_error (
		table   => $self->get_table->get_name,
		column  => $self->get_src_col,
		message => "CREATE REFERENCE needs a DBI handle",
	), return if not $self->get_ddl_object->get_dbh;

	my @sql;
	my $schema = $self->get_ddl_object->get_driver_object->get_schema_object;
	my $table  = $self->get_table->get_name;

	#-- Name des Constraints ermitteln
	my $name = $schema->get_references_href->{
		$table.":".$self->get_src_col.":".
		$self->get_dest_table.":".$self->get_dest_col,
	};

	#-- Fehler, wenn Name nicht bekannt
	if ( not $name ) {
		$self->get_ddl_object->add_error (
			table   => $self->get_table->get_name,
			column  => $self->get_src_col,
			message => "DROP REFERENCE impossible for references ".
				   "created in the same DDL configuration ".
				   "(or the reference simply does not exist)",
		);
		return;
	}

	#-- Foreign Key droppen
	my $ddl_name = $self->get_name;
	my @sql = (
		"# This drops foreign key '$ddl_name'",
		"ALTER TABLE $table DROP FOREIGN KEY $name"
	);
	
	#-- src Index droppen, wenn von Dimedis::Ddl angelegt
	my $src_index = $schema->get_index_by_key
			       ->{$table}
			       ->{$self->get_src_col};
	if ( $src_index =~ /^d3l/ ) {
		push @sql, "DROP INDEX $src_index ON $table";
		$schema->drop_index (
			reference    => $self,
			ref_idx_type => "src",
		);
	}
	
	#-- dest Index droppen, wenn von Dimedis::Ddl angelegt
	my $dest_index = $schema->get_index_by_key
				->{$self->get_dest_table}
				->{$self->get_dest_col};
	if ( $dest_index =~ /^d3l/ ) {
		push @sql, "DROP INDEX $dest_index ON ".$self->get_dest_table;
		$schema->drop_index (
			reference    => $self,
			ref_idx_type => "dest",
		);
	}

	return @sql;
}

package Dimedis::DdlDriver::mysql;

sub get_schema_object		{ shift->{schema_object}		}
sub set_schema_object		{ shift->{schema_object}	= $_[1]	}

sub new {
	my $class = shift;
	my %par = @_;
	my ($ddl) = @par{'ddl'};

	my $schema = Dimedis::Ddl::Schema::mysql->new( ddl => $ddl );

	$schema->analyze_database_schema;
	
	my $self = bless {
		schema_object => $schema,
	}, $class;
	
	return $self;
}

package Dimedis::Ddl::Schema::mysql;

use Carp;

sub get_ddl_object		 { shift->{ddl_object}			}
sub get_index_by_key		 { shift->{index_by_key}		}
sub get_create_table_by_name	 { shift->{create_table_by_name}	}
sub get_create_table_by_name	 { shift->{create_table_by_name}	}
sub get_references_href		 { shift->{references_href}		}

sub new {
	my $class = shift;
	my %par = @_;
	my ($ddl) = @par{'ddl'};

	my $self = bless {
		ddl_object		 => $ddl,      
		index_by_key		 => {},        
		create_table_by_name	 => {},        
		references_href		 => {},    
	}, $class;
	
	return $self;
}

sub analyze_database_schema {
	my $self = shift;
	
	my $dbh = $self->get_ddl_object->get_dbh;
	
	return 1 if not $dbh;	# empty schema if no database is connected
	
	my $raise_error = $dbh->{RaiseError};
	$dbh->{RaiseError} = 1;

	my $sth = $dbh->prepare ( "show variables like 'version'" );
	$sth->execute;
	my (undef, $version) = $sth->fetchrow_array;
	my @v = $version =~ /(\d+)/g;
	my $num_version = $v[0]*10000+$v[1]*100+$v[2];

	$self->get_ddl_object->add_error (
		message => "MySQL version >= 4.0.13 required, ".
			   "installed is only version $version"
	), return if $num_version < 40013;
	
	$sth = $dbh->prepare ( "show tables" );
	$sth->execute;

	my $table;
	while ( ($table) = $sth->fetchrow_array ) {
		my $sth = $dbh->prepare ( "show create table $table" );
		$sth->execute;
		my (undef, $sql) = $sth->fetchrow_array;
		$sth->finish;

		$self->get_create_table_by_name->{$table} = $sql;

		my ($name, $columns, $ref_table);

		# primary key
		if ( ($columns) = $sql =~ /primary\s+key\s+\((.*)\)/i ) {
			$columns =~ s/[`'"]//g;
			$columns =~ s/\s+//g;
			$self->get_index_by_key
			     ->{$table}->{$columns} = "_primary_key";
		}

		# normal keys (index)
		while ( $sql =~ /,\s+(unique\s+)?key\s+\W(\w+)\W\s+\((.*?)\)/sig ) {
			($name, $columns) = ($2, $3);
			$columns =~ s/[`'"]//g;
			$columns =~ s/\s+//g;
			$self->get_index_by_key
			     ->{$table}->{$columns} = $name;
		}

		# foreign keys (reference)
		my ($name, $src_col, $dest_table, $dest_col);
		while ( $sql =~ /constraint\s+\W(.*?)\W\s+	# name
				 foreign\s+key\s+
				 \((.*?)\)\s+			# src_col
				 references\s+\W(\w+)\W\s+	# dest_table
				 \((.*?)\)			# dest_col
				 /sigx ) {
			($name, $src_col, $dest_table, $dest_col) =
				($1, $2, $3, $4);
			$src_col =~ s/[`'"]//g;
			$src_col =~ s/\s//g;
			$dest_col =~ s/[`'"]//g;
			$dest_col =~ s/\s//g;
			$self->get_references_href
			     ->{"$table:$src_col:$dest_table:$dest_col"} = $name;
		}
	}

	$sth->finish;
	
	$dbh->{RaiseError} = $raise_error;

	return 1;
}

sub add_index {
	my $self = shift;
	my %par = @_;
	my  ($index, $constraint, $reference, $ref_idx_type) =
	@par{'index','constraint','reference','ref_idx_type'};

	#-- Index in internes Schema Objekt aufnehmen

	if ( $index ) {
		$self->get_index_by_key
		     ->{$index->get_table->get_name}
		     ->{$index->get_on} = $index->get_name;

	} elsif ( $constraint ) {
		$self->get_index_by_key
		     ->{$constraint->get_table->get_name}
		     ->{$constraint->get_unique} = $constraint->get_name;

	} elsif ( $reference ) {
		if ( $ref_idx_type eq 'src' ) {
			$self->get_index_by_key
			     ->{$reference->get_table->get_name}
			     ->{$reference->get_src_col} = "d3l_".
			       $reference->get_name;
		} elsif ( $ref_idx_type eq 'dest' ) {
			$self->get_index_by_key
			       ->{$reference->get_dest_table}
			       ->{$reference->get_dest_col} = "d3l_".
			         $reference->get_name."_dest";
		} else {
			croak "Illegal 'ref_idx_type'";
		}
	}
	
	1;
}

sub drop_index {
	my $self = shift;
	my %par = @_;
	my  ($index, $constraint, $reference, $ref_idx_type) =
	@par{'index','constraint','reference','ref_idx_type'};

	#-- Index aus internen Schema Objekt entfernen

	if ( $index ) {
		delete $self->get_index_by_key
			    ->{$index->get_table->get_name}
			    ->{$index->get_on};

	} elsif ( $constraint ) {
		delete $self->get_index_by_key
		       	    ->{$constraint->get_table->get_name}
		            ->{$constraint->get_unique};

	} elsif ( $reference and $ref_idx_type eq 'src' ) {
		delete $self->get_index_by_key
		       	    ->{$reference->get_table->get_name}
		            ->{$reference->get_src_col};
	} elsif ( $reference and $ref_idx_type eq 'dest' ) {
		delete $self->get_index_by_key
		       	    ->{$reference->get_name}
		            ->{$reference->get_dest_col};
	}

	1;
}

1;
