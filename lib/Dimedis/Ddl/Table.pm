package Dimedis::Ddl::Table;

use Dimedis::Ddl::Column;
use Dimedis::Ddl::Index;
use Dimedis::Ddl::Reference;
use Dimedis::Ddl::Constraint;
use Dimedis::Ddl::PrimaryKey;

use Carp;
use strict;

sub get_name			{ shift->{name}				}
sub get_type_hash_only		{ shift->{type_hash_only}		}
sub get_columns			{ shift->{columns}			}
sub get_column_order		{ shift->{column_order}			}
sub get_primary_key		{ shift->{primary_key}			}
sub get_indices			{ shift->{indices}			}
sub get_references		{ shift->{references}			}
sub get_constraints		{ shift->{constraints}			}
sub get_db_specific		{ shift->{db_specific}			}
sub get_alter_state		{ shift->{alter_state}			}
sub get_alter_cases		{ shift->{alter_cases}			}
sub get_ddl_object		{ shift->{ddl_object}			}
sub add_error			{ shift->get_ddl_object->add_error(@_)	}

sub get_driver_object		{ shift->{driver_object}		}
sub set_driver_object		{ shift->{driver_object}	= $_[1]	}

sub set_primary_key		{ shift->{primary_key}		= $_[1]	}

sub get_is_clean		{ shift->{is_clean}			}
sub set_is_clean		{ shift->{is_clean}		= $_[1]	}

sub new_from_config {
	my $class = shift;
	my %par = @_;
	my  ($name, $ddl, $config_lref) =
	@par{'name','ddl','config_lref'};
	
	my ($column_class, $index_class, $constraint_class, $reference_class,
	    $primary_key_class) = ($class, $class, $class, $class, $class);

	$column_class      =~ s/^Dimedis::Ddl::Table/Dimedis::Ddl::Column/;
	$index_class       =~ s/^Dimedis::Ddl::Table/Dimedis::Ddl::Index/;
	$constraint_class  =~ s/^Dimedis::Ddl::Table/Dimedis::Ddl::Constraint/;
	$reference_class   =~ s/^Dimedis::Ddl::Table/Dimedis::Ddl::Reference/;
	$primary_key_class =~ s/^Dimedis::Ddl::Table/Dimedis::Ddl::PrimaryKey/;

	my $db_type = $ddl->get_db_type;

	my ($primary_key, @indices, @references, @constraints, @alter_cases,
	    $item, $db_specific, $value, @columns, @column_order, %columns_hash);

	@column_order = grep { !/^_/ } @{$config_lref};

	my $self = bless {
		name		 => $name,
		ddl_object       => $ddl,
		column_order     => \@column_order,
		columns          => \@columns,
		indices    	 => \@indices,
		references 	 => \@references,
		constraints 	 => \@constraints,
		alter_cases	 => \@alter_cases,
	}, $class;

	my ($column_name, $value, $alter_state, $type_hash_only);

	$alter_state = "";

	for ( my $i=0; $i < @{$config_lref}; $i+=2) {
		$column_name  = $config_lref->[$i];
		$value        = $config_lref->[$i+1];

		if ( $column_name !~ /^_/ ) {
			# normale Tabellenspalte
			$alter_state ||= "create";

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "Multiple instance of column"
			), next if $alter_state eq 'create' and
			           exists $columns_hash{$column_name};

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message =>  "No definitions allowed in drop_table mode"
			), next if $alter_state eq 'drop_table';

			$item = $column_class->new_from_config (
				name         => $column_name,
				table        => $self,
				config_value => $value,
				alter_state  => $alter_state,
			);

			$columns_hash{$column_name} = $item;
			push @alter_cases, $item if $item and $alter_state ne 'create';
			push @columns, $item     if $item and $alter_state eq 'create';

		} elsif ( $column_name eq "_alter" ) {
			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "_alter in table create mode not allowed"
			), next if $alter_state eq 'create';

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "unknown _alter specification '$value'"
			), next	if $value !~ /^(add|modify|drop|drop_table)$/;

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "No definitions allowed in drop_table mode"
			), next if $alter_state eq 'drop_table';

			$alter_state = $value;

		} elsif ( $column_name eq "_primary_key" ) {
			# Primary Key
			$value = $self->convert_config_value ( value => $value );

			$self->add_error (
				table   => $name,
				column  => $value,
				message => "double primary key definition $name.$value->{column}"
			), next if defined $primary_key;

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "No definitions allowed in drop_table mode"
			), next if $alter_state eq 'drop_table';

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "missing _alter option or wrong order (specify columns first)"
			), next if $alter_state eq '';

			# Primary Key
			$item = $primary_key_class->new_from_config (
				table        => $self,
				config_value => $value,
				alter_state  => $alter_state,
			);

			push @alter_cases, $item if $item and $alter_state ne 'create';
			$primary_key = $item     if $item and $alter_state eq 'create';

		} elsif ( $column_name eq "_index" ) {
			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "No definitions allowed in drop_table mode"
			), next if $alter_state eq 'drop_table';

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "missing _alter option or wrong order (specify columns first)"
			), next if $alter_state eq '';

			# Index
			$item = $index_class->new_from_config (
				table        => $self,
				config_value => $self->convert_config_value ( value => $value ),
				alter_state  => $alter_state,
			);
			push @alter_cases, $item if $item and $alter_state ne 'create';
			push @indices,     $item if $item;

		} elsif ( $column_name eq "_constraint" ) {
			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "No definitions allowed in drop_table mode"
			), next if $alter_state eq 'drop_table';

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "missing _alter option or wrong order (specify columns first)"
			), next if $alter_state eq '';

			# Constraint
			$item = $constraint_class->new_from_config (
				table        => $self,
				config_value => $self->convert_config_value ( value => $value ),
				alter_state  => $alter_state,
			);
			push @alter_cases, $item if $item and $alter_state ne 'create';
			push @constraints, $item if $item;

		} elsif ( $column_name =~ /^_references?$/ ) {
			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "No definitions allowed in drop_table mode"
			), next if $alter_state eq 'drop_table';

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "missing _alter option or wrong order (specify columns first)"
			), next if $alter_state eq '';

			# Reference
			$item = $reference_class->new_from_config (
				table        => $self,
				config_value => $self->convert_config_value ( value => $value ),
				alter_state  => $alter_state,
			);
			push @alter_cases, $item if $item and $alter_state ne 'create';
			push @references,  $item if $item;

		} elsif ( $column_name =~ /_type_hash_only/ ) {
			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "type_hash_only only allowed when creating a table"
			), next if $alter_state ne '' and $alter_state ne 'create';

			$type_hash_only = $value;

		} elsif ( $column_name =~ /_db_$db_type$/ ) {
			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "No definitions allowed in drop_table mode"
			), next if $alter_state eq 'drop_table';

			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "missing _alter option or wrong order (specify columns first)"
			), next if $alter_state eq '';

			# DB specific
			$db_specific = $self->convert_config_value ( value => $value );

		} elsif ( $column_name !~ /_db/ ) {
			# keine andere datenbankspezifische Angabe:
			# => unbekannte Bezeichnung
			$self->add_error (
				table   => $name,
				column  => $column_name,
				message => "Unknown specification '$column_name'"
			);
			next;
		}
	}

	push @alter_cases, "drop_table" if $alter_state eq 'drop_table';

	$db_specific ||= {};

	$self->{primary_key}    = $primary_key if $alter_state eq 'create';
	$self->{db_specific}    = $db_specific;
	$self->{alter_state}    = $alter_state eq 'create' ? 'create' : 'alter';
	$self->{type_hash_only} = $type_hash_only;

	return $self;
}

sub get_columns_ddl {
	my $self = shift;
	my %par = @_;
	my ($add_last_comma) = @par{'add_last_comma'};

	my $sql = "";
	my $columns = $self->get_columns;
	my $last_column = $columns->[@{$columns}-1];
	my $comment;
	foreach my $column ( @{$columns} ) {
		$sql .= "        ".$column->get_ddl;
		$sql .= "," if $column ne $last_column or $add_last_comma;
		$comment = $column->get_comment_ddl;
		$sql .= "        $comment" if $comment;
		$sql .= "\n" if $column ne $last_column;
	}
	
	return $sql;
}

sub get_create_constraints_ddl {
	my $self = shift;
	
	return if $self->get_type_hash_only;

	my @sql;
	my $constraints = $self->get_constraints;
	my @tmp_sql;
	foreach my $constraint ( @{$constraints} ) {
		if ( $constraint->get_alter_state eq 'create' or
		     $constraint->get_alter_state eq 'add' or
		     $constraint->get_alter_state eq 'modify') {
			@tmp_sql = $constraint->get_create_ddl;
		}
		push @sql, @tmp_sql;
	}
	
	return @sql;
}

sub get_create_references_ddl {
	my $self = shift;

	return if $self->get_type_hash_only;

	my @sql;
	my $references = $self->get_references;

	my @tmp_sql;
	foreach my $reference ( @{$references} ) {
		if ( $reference->get_alter_state eq 'create' or
		     $reference->get_alter_state eq 'add' or
		     $reference->get_alter_state eq 'modify') {
			@tmp_sql = $reference->get_create_ddl;
		}
		next if not @tmp_sql;
		push @sql, @tmp_sql;
	}
	
	return @sql;
}

sub get_create_indices_ddl {
	my $self = shift;
	
	return if $self->get_type_hash_only;

	my @sql;
	my $indices = $self->get_indices;
	my @tmp_sql;
	foreach my $index ( @{$indices} ) {
		if ( $index->get_alter_state eq 'create' or
		     $index->get_alter_state eq 'add' or
		     $index->get_alter_state eq 'modify') {
			@tmp_sql = $index->get_create_ddl;
		}
		push @sql, @tmp_sql;
	}
	
	return @sql;
}

sub get_drop_constraints_ddl {
	my $self = shift;
	
	return if $self->get_type_hash_only;

	my @sql;
	my $constraints = $self->get_constraints;
	my @tmp_sql;
	foreach my $constraint ( @{$constraints} ) {
		@tmp_sql = $constraint->get_drop_ddl;
		push @sql, @tmp_sql;
	}

	return @sql;
}

sub get_drop_references_ddl {
	my $self = shift;
	
	return if $self->get_type_hash_only;

	my @sql;
	my $references = $self->get_references;
	my @tmp_sql;
	foreach my $reference ( @{$references} ) {
		@tmp_sql = $reference->get_drop_ddl;
		push @sql, @tmp_sql;
	}
	
	return @sql;
}

sub get_drop_indices_ddl {
	my $self = shift;
	
	return if $self->get_type_hash_only;

	my @sql;
	my $indices = $self->get_indices;
	my @tmp_sql;
	foreach my $index ( @{$indices} ) {
		@tmp_sql = $index->get_drop_ddl;
		push @sql, @tmp_sql;
	}
	
	return @sql;
}

sub get_create_or_alter_ddl {
	my $self = shift;
	my %par = @_;
	my ($all) = @par{'all'};

	return if $self->get_type_hash_only;

	if ( $self->get_alter_state eq 'alter' ) {
		return $self->get_alter_ddl;

	} elsif ( not $all ) {
		return $self->get_create_ddl;

	} else {
		my @sql = $self->get_create_ddl;
		push @sql, $self->get_create_indices_ddl;
		push @sql, $self->get_create_constraints_ddl;
		push @sql, $self->get_create_references_ddl;
		return @sql;
	}
}

sub get_create_ddl {
	my $self = shift;

	return if $self->get_type_hash_only;

	my $sql = "CREATE TABLE ".$self->get_name." (\n";

	my $primary_key_sql = "";
	$primary_key_sql = $self->get_primary_key->get_ddl
		if defined $self->get_primary_key;

	my $columns_sql = $self->get_columns_ddl (
		add_last_comma => $primary_key_sql ? 1 : 0
	);

	$sql .= $columns_sql;

	my $add_sql = "";
	$add_sql .= ",\n        $primary_key_sql" if $primary_key_sql;

	$add_sql =~ s/^,//;

	$sql .= "$add_sql\n)";

	return $sql;
}

sub get_alter_ddl {
	my $self = shift;
	
	if ( $self->get_alter_cases->[0] eq 'drop_table' ) {
		return $self->get_drop_ddl;
	}
	
	my (@sql, $method);
	foreach my $case ( @{$self->get_alter_cases} ) {
		# wenn wir nicht im "create_all" Modus sind,
		# werden hier nur Spaltenänderungen durchgeführt,
		# aber keine Änderungen an anderen Typen
		# (References, Constraints etc.)
		next if $self->get_ddl_object->get_mode ne 'create_all' and
			ref ($case) !~ /Column/;

		$method = "get_alter_".$case->get_alter_state."_ddl";
		push @sql, $case->$method();
	}

	return @sql;
}

sub get_drop_ddl {
	my $self = shift;
	my %par = @_;
	my ($all) = @par{'all'};

	return if $self->get_type_hash_only;

	my $drop_sql = "DROP TABLE ".$self->get_name;
	return ($drop_sql) if not $all;

	my @sql;
	push @sql, $self->get_drop_indices_ddl;
	push @sql, $self->get_drop_references_ddl;
	push @sql, $self->get_drop_constraints_ddl;
	push @sql, $drop_sql;

	return @sql;
}

sub get_type_hash {
	my $self = shift;
	my %par = @_;
	my ($full) = @par{'full'};

	my %type_hash;

	foreach my $c ( @{$self->get_columns} ) {
		next if not $full and
			$c->get_type ne 'native_date' and
			$c->get_type ne 'serial' and
			$c->get_type ne 'blob' and
			$c->get_type ne 'clob';
		$type_hash{$c->get_name} = lc($c->get_full_type);
	}
	
	return \%type_hash;
}

sub alter_type_hash {
	my $self = shift;
	my %par = @_;
	my  ($full, $column, $type_href) =
	@par{'full','column','type_href'};

	return if not $full and
		  $column->get_type ne 'native_date' and
		  $column->get_type ne 'serial' and
		  $column->get_type ne 'blob' and
		  $column->get_type ne 'clob';

	if ( $column->get_alter_state eq 'drop' ) {
		# column is dropped
		delete $type_href->{$column->get_name};
	} else {
		# column is added or modified
		$type_href->{$column->get_name} = lc($column->get_full_type);
	}

	1;
}

sub convert_config_value {
	my $self = shift;
	my %par = @_;
	my ($value) = @par{'value'};
	
	return $value if ref $value eq 'HASH';
	return {}     if ref $value ne 'ARRAY';
	
	my %hash = @{$value};
	
	return \%hash;
}

1;
