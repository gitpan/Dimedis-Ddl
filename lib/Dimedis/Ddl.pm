package Dimedis::Ddl;

$VERSION = "0.37";

use Carp;
use strict;

use Dimedis::Ddl::Table;
use Dimedis::Ddl::Config;

use Text::Tabs;
use Data::Dumper;

# öffentliche Attribute
sub get_db_type			{ shift->{db_type}			}
sub get_type_hash_ref		{ shift->{type_hash_ref}		}
sub get_type_hash_lref		{ shift->{type_hash_lref}		}
sub get_hint			{ shift->{hint_hash_ref}->{$_[0]}	}
sub get_driver_object		{ shift->{driver_object}		}

sub get_dbh			{ shift->{dbh}				}

sub get_mode			{ shift->{mode}				}
sub set_mode			{ shift->{mode}			= $_[1]	}

sub get_ddl_llref		{
	my $self = shift;
	return [] if $self->has_errors;
	return $self->{ddl_llref};
}

sub set_ddl_llref		{ shift->{ddl_llref}		= $_[1]	}

sub set_hint	{ my $s = shift; $s->{hint_hash_ref}->{$_[0]} = $_[1] 	}

# private Attribute
sub get_tables			{ shift->{tables}			}
sub get_tables_hash		{ shift->{tables_hash}			}
sub get_errors_lref		{ shift->{errors_lref}			}
sub initialized			{ shift->{initialized}			}
sub get_croak_config_errors	{ shift->{croak_config_errors}		}

# das Setzen der Attribute sollte nicht von außen gemacht werden
sub set_tables			{ shift->{tables}		= $_[1]	}
sub set_tables_hash		{ shift->{tables_hash}		= $_[1]	}
sub set_initialized		{ shift->{initialized}		= $_[1]	}
sub set_type_hash_ref		{ shift->{type_hash_ref}	= $_[1]	}
sub set_type_hash_lref		{ shift->{type_hash_lref}	= $_[1]	}
sub set_croak_config_errors	{ shift->{croak_config_errors}	= $_[1]	}

# alle anderen Methoden sind öffentlich
sub new {
	my $class = shift;
	my %par = @_;
	my  ($dbh, $db_type, $dir, $filename, $config, $croak_config_errors) =
	@par{'dbh','db_type','dir','filename','config','croak_config_errors'};
	
	croak "Specify dbh or db_type"
		if not $db_type and not $dbh;

	croak "You must specify a dbh for MySQL databases"
		if $db_type eq 'mysql' and not $dbh;

	$db_type ||= $dbh->{Driver}->{Name} if $dbh;
	$croak_config_errors = 1 if not defined $croak_config_errors;

	my $cfg_src = 0;
	++$cfg_src if $dir;
	++$cfg_src if $filename;
	++$cfg_src if $config;
	
	croak "provide max. one of dir, filename or config"
		if $cfg_src > 1;

	my $driver_class = "Dimedis::DdlDriver::$db_type";
	
	eval "use $driver_class";
	croak "Can't load $driver_class: $@" if $@;

	my $self = bless {
		dbh		    => $dbh,
		db_type             => $db_type,
		croak_config_errors => $croak_config_errors,
		ddl_llref           => [],
		errors_lref         => [],
		type_hash_ref	    => {},
		type_hash_lref      => [],
		hint_hash_ref       => {},
	}, $class;

	my $driver_object;
	$driver_object = $driver_class->new ( ddl => $self )
		if $driver_class->can ("new");

	$self->{driver_object} = $driver_object;

	if ( $filename ) {
		$config = Dimedis::Ddl::Config->new;
		$config->add_file (
			filename => $filename
		);
	} elsif ( $dir ) {
		$config = Dimedis::Ddl::Config->new;
		$config->add_directory (
			dir => $dir
		);
	}

	$self->init_from_config (
		config => $config,
	) if $config;

	return $self;
}

sub init_from_config {
	my $self = shift;
	my %par = @_;
	my ($config_lref, $config) = @par{'config_lref','config'};
	
	$config_lref ||= $config->get_data;
	
	my $table_class = "Dimedis::Ddl::Table::".$self->get_db_type;

	my @tables;
	my %tables;
	$self->set_tables ( \@tables );
	$self->set_tables_hash ( \%tables );

	my ($table_name, $value);
	for ( my $i=0; $i < @{$config_lref}; ) {
		$table_name = $config_lref->[$i];
		$value      = $config_lref->[$i+1];
		push @tables, $tables{$table_name} =
		    $table_class->new_from_config (
		    	name        => $table_name,
		    	ddl         => $self,
			config_lref => $value,
		    );
		$i += 2;
	}
	
	$self->set_initialized (1);
	
	croak ${$self->get_formatted_errors_sref}
		if $self->get_croak_config_errors and
		   $self->has_errors;
	
	1;
}

sub get_create_tables {
	my $self = shift;
	my %par = @_;
	my ($all) = @par{'all'};

	croak "not initialized" if not $self->initialized;

	my @sql;
	foreach my $table (  @{$self->get_tables} ) {
		push @sql, $table->get_create_or_alter_ddl (all => $all);
	}

	return \@sql;
}

sub get_create_indices {
	my $self = shift;

	croak "not initialized" if not $self->initialized;
	
	my @sql;
	foreach my $table ( @{$self->get_tables} ) {
		push @sql, $table->get_create_indices_ddl;
	}

	return \@sql;
}

sub get_create_references {
	my $self = shift;
	
	croak "not initialized" if not $self->initialized;
	
	my @sql;
	foreach my $table ( @{$self->get_tables} ) {
		push @sql, $table->get_create_references_ddl;
	}

	return \@sql;
}

sub get_create_constraints {
	my $self = shift;
	
	croak "not initialized" if not $self->initialized;
	
	my @sql;
	foreach my $table ( @{$self->get_tables} ) {
		push @sql, $table->get_create_constraints_ddl;
	}

	return \@sql;
}

sub get_drop_tables {
	my $self = shift;
	my %par = @_;
	my ($all) = @par{'all'};
	
	croak "not initialized" if not $self->initialized;
	
	my @sql;
	foreach my $table ( reverse @{$self->get_tables} ) {
		push @sql, $table->get_drop_ddl;
	}

	return \@sql;
}

sub get_drop_indices {
	my $self = shift;
	
	croak "not initialized" if not $self->initialized;
	
	my @sql;
	foreach my $table ( @{$self->get_tables} ) {
		push @sql, $table->get_drop_indices_ddl;
	}

	return \@sql;
}

sub get_drop_references {
	my $self = shift;
	
	croak "not initialized" if not $self->initialized;
	
	my @sql;
	foreach my $table ( @{$self->get_tables} ) {
		push @sql, $table->get_drop_references_ddl;
	}

	return \@sql;
}

sub get_drop_constraints {
	my $self = shift;
	
	croak "not initialized" if not $self->initialized;
	
	my @sql;
	foreach my $table ( @{$self->get_tables} ) {
		push @sql, $table->get_drop_constraints_ddl;
	}

	return \@sql;
}

sub clear {
	my $self = shift;
	
	$self->set_ddl_llref([]);
	
	1;
}

sub generate {
	my $self = shift;
	my %par = @_;
	my ($what) = @par{'what'};
	
	$what ||= "create_all";
	
	croak "not initialized" if not $self->initialized;
	
	$self->set_mode ( $what );
	
	if ( $what eq 'create_all' ) {
		push @{$self->get_ddl_llref},
			$self->get_create_tables ( all => 1 );

	} elsif ( $what eq 'drop_all' ) {
		push @{$self->get_ddl_llref},
			$self->get_drop_tables ( all => 1 );

	} else {
		my $method = "get_${what}";
		return $self->add_error (
			message => "Method '$method' not supported"
		) if not $self->can($method);
		push @{$self->get_ddl_llref}, $self->$method();
	}
	
	1;
}

sub print {
	my $self = shift;
	my %par = @_;
	my ($filename) = @par{'filename'};
	
	$filename ||= "-";
	
	croak "not initialized" if not $self->initialized;

	return if $self->has_errors;

	my $fh;
	if ( $filename eq '-' ) {
		$fh = \*STDOUT;
	} else {
		$fh = FileHandle->new;
		if ( $filename =~ /^\s*\|/ ) {
			open ($fh, $filename)
				or croak "can't execute $filename: $!";
		} else {
			open ($fh, "> $filename")
				or croak "can't write $filename: $!";
		}
	}

	my $ddl_llref = $self->get_ddl_llref;
	
	foreach my $sql_code_lref ( @{$ddl_llref} ) {
		foreach my $sql ( @{$sql_code_lref} ) {
			expand($sql);
			print $fh "$sql;\n#----------\n";
		}
	}
	
	close $fh if $filename ne '-';
	
	1;
}

sub execute {
	my $self = shift;
	my %par = @_;
	my ($dbh, $sql_code_lref) = @par{'dbh','sql_code_lref'};
	
	croak "not initialized" if not $self->initialized;

	$dbh ||= $self->get_dbh;

	return if $self->has_errors;

	if ( $sql_code_lref ) {

		foreach my $sql ( @{$sql_code_lref} ) {
			$dbh->do ( $sql );
			croak "DBI\t$DBI::errstr" if $DBI::errstr;
		}

	} else {

		my $sql_code_llref = $self->get_ddl_llref;
	
		foreach my $sql_code_lref ( @{$sql_code_llref} ) {
			foreach my $sql ( @{$sql_code_lref} ) {
				$dbh->do ( $sql );
				croak "DBI\t$DBI::errstr" if $DBI::errstr;
			}
		}

	}

	1;	
}

sub generate_type_hash {
	my $self = shift;
	my %par = @_;
	my ($full) = @par{'full'};

	croak "not initialized" if not $self->initialized;

	return if $self->has_errors;

	my $type_href      = $self->set_type_hash_ref ( {} );
	my $type_href_lref = $self->set_type_hash_lref ( [] );
	
	foreach my $table ( @{$self->get_tables} ) {
		if ( $table->get_alter_state eq 'create' ) {
			# new table got created
			$type_href->{$table->get_name} =
				$table->get_type_hash ( full => $full );
			push @{$type_href_lref}, {
				name  => $table->get_name,
				hash  => $type_href->{$table->get_name},
			};
		} else {
			# existent table is altered
			foreach my $case ( @{$table->get_alter_cases} ) {
				next if not $case->isa ("Dimedis::Ddl::Column");
				$type_href->{$table->get_name} ||= {};
				$table->alter_type_hash (
					full      => $full,
					column    => $case,
					type_href => $type_href->{$table->get_name},
				);
				push @{$type_href_lref}, {
					name  => $table->get_name,
					hash  => $type_href->{$table->get_name},
				};
			}
		}
	}

	1;
}

sub print_type_hash {
	my $self = shift;
	my %par = @_;
	my ($filename, $var) = @par{'filename','var'};

	$filename ||= "-";

	croak "not initialized" if not $self->initialized;

	return if $self->has_errors;
	
	my $fh;
	if ( $filename eq '-' ) {
		$fh = \*STDOUT;
	} else {
		$fh = FileHandle->new;
		if ( $filename =~ /^\s*\|/ ) {
			open ($fh, $filename)
				or croak "can't execute $filename: $!";
		} else {
			open ($fh, "> $filename")
				or croak "can't write $filename: $!";
		}
	}

	if ( not $var ) {
		print $fh "{\n";
	}

	my $type_href_lref = $self->get_type_hash_lref;

	my ($name, $hash, $col, $def);

	foreach my $entry ( @{$type_href_lref} ) {
		$name = $entry->{name};
		$hash = $entry->{hash};

		next if %{$hash} == 0;
	
		if ( $var ) {	
			print $fh "\$$var->\{$name\} = {\n";
		} else {
			print $fh "  $name => {\n";
		}

		foreach $col ( sort keys %{$hash} ) {
			$def = $hash->{$col};
			$def =~ s/'/\\'/g;
			printf $fh "    %-25s => '%s',\n", $col, $def;
		}

		if ( $var ) {
			print $fh "};\n";
		} else {
			print $fh "  },\n";
		}
	}

	if ( $var ) {
		print $fh "\$$var;\n";
	} else {
		print $fh "};\n";
	}

	close $fh if $filename ne '-';

	1;	
}

sub add_error {
	my $self = shift;
	my %par = @_;
	my ($table, $column, $message) = @par{'table','column','message'};
	
	push @{$self->get_errors_lref}, {
		table   => $table,
		column  => $column,
		message => $message,
	};
	
	return;
}

sub has_errors {
	my $self = shift;
	
	return @{$self->get_errors_lref} != 0;
}

sub get_formatted_errors_sref {
	my $self = shift;

	if ( not $self->has_errors ) {
		return \"No errors.\n";
	}

	my $errors;

	require Text::Wrap;
	local ($Text::Wrap::columns) = 47;
	
	$errors .= "The configuration has errors:\n";
	$errors .= "=============================\n\n";

	$errors .= sprintf (
		"%-15s %-15s %s\n",
		"Table", "Column", "Message"
	);

	$errors .= ("=" x 79)."\n";

	foreach my $err ( @{$self->get_errors_lref} ) {
		my @lines =
			split ("\n", Text::Wrap::wrap ('','',$err->{message}));
		$errors .= sprintf (
			"%-15s %-15s %s\n",
			($err->{table}||'-'),
			($err->{column}||'-'),
			shift @lines
		);
		foreach my $line ( @lines ) {
			$errors .=  sprintf ("%-31s %s\n", '', $line);
		}
		$errors .=  ("-" x 79)."\n";
	}
	
	return \$errors;
}

sub print_errors {
	my $self = shift;
	my %par = @_;
	my ($fh) = @par{'fh'};
	
	$fh ||= \*STDERR;
	
	my $errors_sref = $self->get_formatted_errors_sref;
	
	print $fh "\n";
	print $fh ${$errors_sref};
	print $fh "\n";

	1;
}

sub query {
	my $self = shift;
	my %par = @_;
	my ($type, $alter_state) = @par{'type','alter_state'};

	croak "Illegal alter_state '$alter_state"
		if $alter_state ne 'create' and $alter_state ne 'modify' and
		   $alter_state ne 'drop'   and $alter_state ne 'add' and
		   $alter_state ne 'drop_table';

	my ($method, $class);
	if ( $type eq 'column' ) {
		$method = "get_columns";
		$class  = "Dimedis::Ddl::Column";
	} elsif ( $type eq 'index' ) {
		$method = "get_indices";
		$class  = "Dimedis::Ddl::Index";
	} elsif ( $type eq 'reference' ) {
		$method = "get_references";
		$class  = "Dimedis::Ddl::Reference";
	} elsif ( $type eq 'constraint' ) {
		$method = "get_constraints";
		$class  = "Dimedis::Ddl::Constraint";
	} elsif ( $type eq 'primary_key' ) {
		$method = "get_primary_key";
		$class  = "Dimedis::Ddl::PrimaryKey";
	} elsif ( $type ne 'table' ) {
		croak "Illegal object type '$type'";
	}

	my @objects;

	foreach my $table ( @{$self->get_tables} ) {
		if ( $type eq 'table' ) {
			push @objects, $table
				if $table->get_alter_state eq $alter_state;
		} else {
			foreach my $object ( @{$table->$method()},
					     @{$table->get_alter_cases} ) {
				push @objects, $object
				    if $object->isa ( $class ) and
				       $object->get_alter_state eq $alter_state;
			}
		}
	}

	return \@objects;
}

sub cleanup_database {
	my $self = shift;
	
	croak "not initialized" if not $self->initialized;

	return if $self->has_errors;

	my $dbh = $self->get_dbh;
	
	$self->add_error (
		message => "dbh needed to cleanup a database"
	), return if not $dbh;

	$dbh->{AutoCommit} = 0;
	
	eval {
		foreach my $table ( @{$self->get_tables} ) {
			$self->cleanup_table( table => $table );
		}
	};
	
	if ( $@ ) {
		$dbh->rollback;
		die $@;
	}	

	$dbh->commit;
	
	1;
}

sub cleanup_table {
	my $self = shift;
	my %par = @_;
	my ($table) = @par{'table'};

	return if $table->get_is_clean;

	print "* cleanup table ".$table->get_name."\n";

	#-- prevents endless loops for circular references
	$table->set_is_clean(1);
	
	#-- to cleanup a table: first cleanup all referenced
	#-- tables, then the table itself
	my $ref_table;
	foreach my $ref ( @{$table->get_references} ) {
		$ref_table = $self->get_tables_hash->{$ref->get_dest_table};

		croak "Referenced table '".$ref->get_dest_table."' is unknown"
			if not $ref_table;

		#-- cleanup this table first
		$self->cleanup_table (
			table => $ref_table,
		);

		#-- then delete all rows in this table, which
		#-- points to non-existant rows in the
		#-- referenced table
		$self->delete_unreferenced_rows (
			table     => $table,
			reference => $ref,
		);
	}

	1;
}

sub delete_unreferenced_rows {
	my $self = shift;
	my %par = @_;
	my ($table, $reference) = @par{'table','reference'};

	my $src_table  = $table->get_name;
	my $dest_table = $reference->get_dest_table;
	my @src_cols   = split (/,/, $reference->get_src_col);
	my @dest_cols  = split (/,/, $reference->get_dest_col);

	print "* cleanup table $src_table for reference ".
		$reference->get_name."\n";

	require Dimedis::Sql;
	my $dbh = $self->get_dbh;
	my $sqlh = Dimedis::Sql->new ( dbh => $dbh );

	#-- Statement to select all unreferenced rows

	croak "Number of src columns doesn't match dest columns ".
	      "for reference ".$reference->get_name
	      	if @src_cols != @dest_cols;

	my $src_cols =
		"a.".
		join (", a.", @src_cols);

	my ($join_cond, $null_dest_cond, $not_null_src_cond);
	for ( my $i=0; $i < @src_cols; ++$i ) {
		$join_cond .=
			"a.$src_cols[$i]=".
		        "b.$dest_cols[$i] and ";
		$null_dest_cond =
			"b.$dest_cols[$i] is NULL and ";
		$not_null_src_cond =
			"a.$src_cols[$i] is not NULL and ";
	}
	$join_cond =~ s/ and $//;
	$null_dest_cond =~ s/ and $//;
	$not_null_src_cond =~ s/ and $//;

	my ($from, $where) = $sqlh->left_outer_join (
		"$src_table a",
		[ "$dest_table b" ],
		$join_cond
	);

	my $select_unreferenced_rows_sql =
		"select distinct $src_cols
		 from   $from
		 where  $where and $null_dest_cond and
		 	$not_null_src_cond";

	print "  - $select_unreferenced_rows_sql\n";

	my $select_unreferenced_rows_sth =
		$dbh->prepare ($select_unreferenced_rows_sql);

	#-- Statement to delete unreferenced rows

	my $delete_unreferenced_rows_sql =
		"delete from ".$reference->get_table->get_name." ".
		"where ";
		
	foreach my $src_col ( @src_cols ) {
		$delete_unreferenced_rows_sql .= "$src_col=? and ";
	}

	$delete_unreferenced_rows_sql =~ s/ and $//;

	print "  - $delete_unreferenced_rows_sql\n";

	my $delete_unreferenced_rows_sth =
		$dbh->prepare ($delete_unreferenced_rows_sql);

	#-- Select all unreferenced rows from source table,
	#-- and delete them
	
	$select_unreferenced_rows_sth->execute;

	my $cnt;
	while ( my $ar = $select_unreferenced_rows_sth->fetchrow_arrayref ) {
		print "    + ".$reference->get_table->get_name.": delete ".
			   $reference->get_src_col." = ".
			   join (",", @{$ar});
		$cnt = $delete_unreferenced_rows_sth->execute(@{$ar});
		print " => $cnt row(s) deleted\n";
		$delete_unreferenced_rows_sth->finish;
	}

	$select_unreferenced_rows_sth->finish;
	
	1;
}

1;

__END__

=head1 NAME

Dimedis::Ddl - Modul zur datenbankunabhängigen Erzeugung von DDL Code

=head1 SYNOPSIS

  use Dimedis::Ddl;

  # Konstruktor mit oder ohne Initialisierung
  $ddl = Dimedis::Ddl->new ( ... );

  # Nachträgliche Initialisierung
  $ddl->init_from_config ( ... );

  # Spezielle Einstellungen vornehmen
  $ddl->set_hint ( name => $value );

  # Löschen von im Objekt gespeicherten DDL Code
  $ddl->clear;

  # Generierung von DDL Code mit Speicherung im $ddl Objekt
  $ddl->generate ( ... )

  # Ausgabe von im Objekt gespeicherten DDL Code
  $ddl->print ( ... )

  # Ausführung von im Objekt gespeicherten oder übergebenen DDL Code
  $ddl->execute ( ... )

  # Zugriff auf im Objekt gespeicherten DDL Code
  $ddl_llref = $ddl->get_ddl_llref;

  # Generierung des Dimedis::Sql Type Hashes
  $ddl->generate_type_hash;

  # Ausgabe des Dimedis::Sql Type Hashes
  $ddl->print_type_hash ( ... )

  # Zugriff auf das im Objekt gespeicherte Dimedis::Sql Type Hash
  $type_href = $ddl->get_type_hash_ref;
  $type_href_lref = $ddl->get_type_hash_lref;
  
  # Rückgabe von DDL Code zur Erstellung von Tabellen etc.
  $ddl_lref = $ddl->get_create_tables;
  $ddl_lref = $ddl->get_create_indices;
  $ddl_lref = $ddl->get_create_references;
  $ddl_lref = $ddl->get_create_constraints;

  # Rückgabe von DDL Code zur Löschung von Tabellen etc.
  $ddl_lref = $ddl->get_drop_tables;
  $ddl_lref = $ddl->get_drop_indices;
  $ddl_lref = $ddl->get_drop_references;
  $ddl_lref = $ddl->get_drop_constraints;

  # Prüfen ob bei der Generierung Fehler aufgetreten sind
  $has_errors = $ddl->has_errors;

  # Fehlermeldungen formatieren
  $errors_sref = $ddl->get_formatted_errors_sref;
  
  # croak Modus für Konfigurationsfehler abschalten
  $ddl->set_croak_config_errors ( 0 );

  # Fehler ausgeben
  $ddl->print_errors ( ... );

  # DDL Objekte ermitteln
  my $objects = $ddl->query ( ... );

=head1 DESCRIPTION

Dieses Modul korrespondiert mit dem Dimedis::Sql Modul und dient
der Generierung von DDL Code zur Erzeugung von Datenbankobjekten (Tabellen,
Indizies etc.). Dabei wird das Datenmodell anhand einer
datenbankunabhängigigen Perl Datenstruktur beschrieben. Aus dieser
wird dann der datenbankspezifische Code generiert.

Es gibt ein Kommandozeilen-Interface des Moduls namens dddl. Eine
Kurzdokumentation wird bei Aufruf von dddl ohne Parameter
angezeigt, eine ausführliche manpage kann mit "perldoc dddl"
aufgerufen werden.

Die Manpage des Moduls Dimedis::Ddl::Config beschreibt die
Datenstruktur, mit der das Datenmodell definiert wird.

Diese Dokumentation beschreibt die Perl API, mit der die
Dimedis::Ddl Funktionen direkt in Perl Programme eingebunden
werden können.

=head1 METHODEN ZUR INITIALISIERUNG

Der Konstruktor der Dimedis::Ddl Klasse lautet:

  $ddl = Dimedis::Ddl->new (
    [ db_type             => $db_type, ]
    [ dbh                 => $dbh      ],
    [ dir                 => $config_directory, |
    [ croak_config_errors => 0 | 1, ]
      filename            => $config_filename,  |
      config              => $config_object ]
  );

Es muß min. B<db_type> oder B<dbh> angegeben werden. Wenn
B<dbh> angegeben wird, aber kein B<db_type>, ermittelt
Dimedis::Ddl den Datenbanktyp
selbständig (Achtung: es gibt keine "Magie" bezüglich ODBC
und MS-SQL o.ä. an dieser Stelle). Mit B<db_type> kann der
Typ selbst angegeben werden, welcher aus einer bestehenden
Datenbankverbindung wie folgt ermittelt werden kann:

  $dbh->{Driver}->{Name}

Hinweis: für MySQL muß ein dbh angegeben werden, wenn Referenzen
unterstüzt werden sollen.

Mit B<croak_config_errors> kann gesteuert werden, ob Dimedis::Ddl
bei Konfigurationsfehlern eine Exception werfen soll. Näheres
dazu steht im Kapitel zur Fehlerbehandlung weiter unten.

Weiterhin kann optional einer der anderen oben genannten Parameter
angegeben werden, mit denen die Dimedis::Ddl Konfiguration
übergeben wird.

Wenn B<dir> angegeben ist, werden alle Konfigurationsdateien dieses
Verzeichnisses eingelesen. B<filename> gibt den Dateinamen genau
einer zu ladenden Konfigurationsdatei an. Alternativ kann auch
mit B<config> ein Dimedis::Ddl::Config Objekt übergeben werden,
das vorher entsprechend initialisiert wurde (siehe nächster Abschnitt).

Wenn keiner der zusätzlichen Parameter angegeben wurde, ist das
Objekt noch nicht initialisiert. In diesem Fall muß vor Aufruf
der Generierungsmethoden die Initialisierung mit der B<init_from_config>
Methode nachgeholt werden. Diese erwartet ein Dimedis::Ddl::Config
Objekt als Parameter:

  $ddl->init_from_config (
      config => $config_object
  );

Andernfalls wird eine Exception geworfen, wenn anderweitig auf ein nicht
initialisiertes Objekt zugegeriffen wird.

=head2 Wichtige Hinweise zu MySQL

Es muß MySQL Version 4.0.12 oder höher verwendet werden.

Die Angabe des DBI Handles ist zwingend.
Es muß eine Verbindung zur aktuellen Datenbank hergestellt werden,
da der MySQL DDL Treiber die existierende Datenbank analysiert.
Nur mit dieser Information ist es möglich Referenzen anzulegen oder
zu ändern.

B<WARNUNG:>

DROP/MODIFY REFERENCE bewirkt ein Neuerstellen aller Tabellen,
die selbst eine Referenz auf die aktuelle Tabelle haben. Das
Verändern einer Referenz an einer zentralen Tabelle ist also
u.U. sehr zeitaufwändig und insbesondere nicht transaktionssicher.
Während eines solchen Update Vorgangs sollten also keine anderen
Benutzer auf die Datenbank Zugriff haben.

=head2 Erzeugung eines Dimedis::Ddl::Config Objektes

Es gibt drei Möglichkeiten ein Dimedis::Ddl::Config Objekt zu erzeugen
bzw. zu initialisieren:

  $config = Dimedis::Ddl::Config->new ( [ data => $data ] );
  $config->add_file ( filename => $filename );
  $config->add_directory ( dir => $dir, filter_regex => '\.conf$' );

Der B<data> Parameter der B<new> Methode erwartet die verschachtelte
Listenstruktur die weiter oben beschrieben ist. B<add_file>
erwartet den Dateinamen einer Konfigurationsdatei und B<add_directory>
den Namen des Verzeichnisses, dessen Dateien als Konfigurationsdateien
eingelesen werden und der internen Konfiguration hinzugefügt werden
sollen.

Wenn beim Einlesen der Dateien ein Fehler auftritt, wird eine
Exception geworfen.

Optional kann mit B<filter_regex> ein regulärer Ausdruck angegeben
werden, auf den die zu ladenden Dateinamen in dem Verzeichnis passen müssen.
Unterverzeichnisse werden automatisch ausgeschlossen, hierfür muß
B<filter_regex> also nicht herangezogen werden.

=head1 SPEZIELLE EINSTELLUNGEN VORNEHMEN

Um datenbankspezifisch flexibel Code generieren zu können, ohne dafür
datenbankspezifische Methoden einzuführen, gibt es die B<set_hint>
Methode. Mit dieser können optionale Parameter gesetzt werden, die
von den Datenbanktreibern verwendet werden, die das entsprechende
Feature unterstützen.

Derzeibt gibt es hier folgende Parameter:

B<create_oracle_sequence>=B<1>
    CREATE und DROP SEQUENCE Befehle werden
    für Oracle beim Tabellen anlegen/löschen
    mit erzeugt. Default ist hier 0.

=head1 METHODEN ZUR DDL CODE GENERIERUNG

Dimedis::Ddl hat Methoden zur Generierung von DDL Code, der im
Dimedis::Ddl Objekt gespeichert wird und mit weiteren Methoden
ausgegeben oder ausgeführt werden kann.

=head2 Gespeicherten DDL Code löschen

  $ddl->clear;

Die B<clear> Methode löscht im Objekt gespeicherten DDL Code.

=head2 DDL Code generieren

  $ddl->generate ( [ what => $what ] );

Diese Methode ist ein Frontend gegen die zahlreichen einzelnen
Methoden zur Generierung von speziellem DDL Code. Über den B<what>
Parameter wird gesteuert, welcher Code generiert werden soll,
Default ist 'create_all'.
Dieser Parameter entspricht exakt der B<-w> Option des B<dddl>
Kommandos:

  create_all		alles anlegen
  create_tables		Tabellen anlegen
  create_references	Referenzen anlegen
  create_constraints	Constraints anlegen
  create_indices	Indices anlegen

  drop_all		alles löschen
  drop_tables		Tabellen löschen
  drop_references	Referenzen löschen
  drop_constraints	Constraints löschen
  drop_indices          Indices löschen

Der DDL Code wird generiert und im Dimedis::Ddl Objekt gespeichert.

=head2 DDL Code ausgeben

  $ddl->print ( [ filename => $filename ] );

Die B<print> Methode gibt den generierten DDL Code aus bzw. schreibt
ihn in die mit B<filename> angegebene Datei. Wenn als Dateiname
ein - übergeben wird, so werden die Daten auf STDOUT ausgegeben.
Wird der filename Parameter weggelassen, so wird auf STDOUT geschrieben.
Als Dateiname kann auch eine Pipe (z.B. "| grep foo") angegeben
werden, dann werden die Daten entsprechend in diese Pipe geschrieben.

=head2 DDL Code ausführen

  $ddl->execute (
    dbh => $dbh,
    [ sql_code_lref => $sql_code_lref ]
  );

Diese Methode führt SQL bzw. DDL Code aus, wobei der auszuführende Code
mit dem B<sql_code_lref> Parameter als Listenreferenz übergeben werden
kann. In der Liste darf jedes Element nur genau einen SQL Befehl enthalten.

Wenn der B<sql_code_lref> Parameter weggelassen wird, wird der
intern gespeicherte bzw. vorher generierte Code ausgeführt.

Die Angabe von B<dbh> ist zwingend und muß ein verbundenes DBI Connection
Objekt enthalten.

Wenn bei der Ausführung der Befehle ein Fehler auftritt, so bricht
die Methode die Ausführung mit einer entsprechenden Exception ab.

Wenn also eine feinere Fehlerkontrolle gewünscht wird, so sollte mit
B<$ddl-E<gt>get_ddl_llref> (siehe unten) der DDL Code abgerufen werden,
um diesen dann selbst mit B<DBI-E<gt>do> auszuführen.

=head2 Zugriff auf im Dimedis::Ddl Objekt gespeicherten Code

  $ddl_llref = $ddl->get_ddl_llref;

Die B<get_ddl_llref> Methode gibt eine Liste von Listen zurück,
die den generierten DDL Code enthalten. Es folgt ein kurzes
Beispiel zum Zugriff auf die gelieferten Daten:

  $ddl_llref = $ddl->get_ddl_llref;

  foreach my $ddl_lref ( @{$ddl_llref} ) {
      foreach my $ddl_code ( @{$ddl_lref} ) {
          $dbi->do ( $ddl_code );
      }
  }

=head2 Dimedis::Sql Type Hash generieren

  $ddl->generate_type_hash ( [ full => 0 | 1 ] );

Die B<generate_type_hash> Methode generiert den Dimedis::Sql Type Hash
und speichert ihn im Objekt. Dabei gibt es zwei Varianten, die über
die Option B<full> unterschieden werden. Ein eventuell im Objekt schon
vorhandenes Type Hash wird überschrieben.

Per Default (full => 0) wird ein minimales Type Hash ausgegeben, das
für die Verwendung mit Dimedis::Sql ausreicht. Hier sind nur 'serial',
'blob', 'clob' und 'native_date' Spalten enthalten. Alle anderen
Typen werden von Dimedis::Sql auch ohne Angabe im Type Hash korrekt
verarbeitet.

Mit full => 1 werden alle Spalten ausgegeben. Das Import/Export
Programm von Dimedis::Sql benötigt ein vollständiges Type Hash.

=head2 Dimedis::Sql Type Hash ausgeben

  $ddl->print_type_hash ( [ filename => $filename ] [, var => $var ] );

Diese Methode gibt den mit B<generate_type_hash> generierten Type Hash
aus. Für B<filename> gilt dasselbe wie bei der B<print> Methode: ein
- Zeichen signalisiert die Ausgabe auf STDOUT, für andere Werte wird das
Ergebnis in die entsprechende Datei geschrieben. Wird der filename
Parameter weggelassen, so wird auf STDOUT geschrieben.
Als Dateiname kann auch eine Pipe (z.B. "| grep foo") angegeben
werden, dann werden die Daten entsprechend in diese Pipe geschrieben.

Der B<var> Parameter gibt den Namen der Variablen an (ohne das $ Zeichen),
die für die Zuweisung in dem Dump des Type Hashs verwendet werden soll.
Wenn B<var> fehlt, wird eine anonyme Hash Referenz ausgegeben.

Die Ausgabe erfolgt in der Reihenfolge, in der die Tabellen in der
Konfiguration definiert wurden.

=head2 Zugriff auf im Dimedis::Ddl Objekt gespeichertes Type Hash 

  $type_href = $ddl->get_type_hash_ref;

Die B<get_type_hash_ref> Methode gibt eine Referenz auf das zuvor
generierte und im Objekt gespeicherte Dimedis::Sql Type Hash zurück.

  $type_href_lref = $ddl->get_type_hash_lref;

Die B<get_type_hash_lref> Methode gibt das Type Hash in der Reihenfolge
zurück, in der die Tabellen in der Konfiguration auftraten. Ergebnis
ist eine Referenz auf eine Liste von Hashes, die folgende Schlüssel
definieren:

  name    Name der Tabelle
  hash    Type-Hash der Tabelle

=head1 RÜCKGABE VON GENERIERTEM DDL CODE

Die oben genannten Methoden generieren DDL Code und speichern diesen
im Objekt bzw. greifen auf intern gespeicherten Code zu. Es ist
auch möglich den Code über spezifische Methoden zu generieren und ihn
sich zurückgeben zu lassen, ohne daß dieser im Objekt gespeichert wird.

Folgende Methoden stehen dafür zur Verfügung:

  # Rückgabe von DDL Code zur Erstellung von Tabellen etc.
  $ddl_lref = $ddl->get_create_tables;
  $ddl_lref = $ddl->get_create_indices;
  $ddl_lref = $ddl->get_create_references;
  $ddl_lref = $ddl->get_create_constraints;

  # Rückgabe von DDL Code zur Löschung von Tabellen etc.
  $ddl_lref = $ddl->get_drop_tables;
  $ddl_lref = $ddl->get_drop_indices;
  $ddl_lref = $ddl->get_drop_references;
  $ddl_lref = $ddl->get_drop_constraints;

Der Rückgabewert dieser Methoden eignet sich zur Übergabe an
die B<execute> Methode und ist eine Referenz auf eine Liste
von DDL Befehlen, die z.B. auch einzeln mittels B<DBI-E<gt>do>
ausgeführt werden können.

=head1 FEHLERBEHANDLUNG

Bei allen Methoden zur Generierung von DDL Code können Fehler
auftreten, wenn die Konfiguration nicht korrekt ist. Mit
der Methode

  $ddl->set_croak_config_errors ( 0 | 1 );

kann gesteuert werden, ob Dimedis::Ddl in diesem Fall eine Exception
werfen soll oder nicht. Per Default wird eine Exception geworfen,
d.h. B<croak_config_errors> ist auf 1 gesetzt.

Ob Fehler vorliegen, kann kann jederzeit abgefragt werden:

  $has_errors = $ddl->has_errors;

Die Fehlermeldungen können formatiert werden:

  $errors_sref = $ddl->get_formatted_errors_sref;

oder direkt formatiert ausgegeben werden (per Default auf STDERR
oder auf ein gegebenes Filehandle):

  $ddl->print_errors ( fh => \*STDOUT );
  
Weiterhin wird Dimedis::Ddl::Config Exceptions, wenn beim Einlesen
von Dateien oder Directories ein Fehler auftritt.

Eine Ausgabe von generiertem Code wird generell unterbunden, sobald
ein Fehler aufgetreten ist.

=head1 DDL Objekte ermitteln

[ experimentell, nicht alle Kombinationen getestet ]

Es gibt eine eingeschränkte Möglichkeit die aufgrund der
Konfigurationsdatei erzeugten internen DDL Objekte zu analysieren
(Dimedis::Ddl::Table, Dimedis::Ddl::Column, Dimedis::Ddl::Index,
Dimedis::Ddl::PrimaryKey, Dimedis::Ddl::Constraint,
Dimedis::Ddl::Reference):

  $objects = $ddl->query (

    type => 'table'       | 'column'     | 'index'  |
    	    'primary_key' | 'constraint' | 'reference',

    alter_state => 'create'     | 'add'  | 'modify' |
    		   'drop_table' | 'drop'

  );

Es kann also nach Datentyp unterschieden werden, sowie der
Operation, die mit diesem durchgeführt wird.

Zurückgegeben werden die entsprechenden Dimedis::Ddl intern
erzeugten Objekte für diesen Datentyp, die einen entsprechenden
alter_state haben.

=head1 AUTOR

Joern Reder <joern@dimedis.de>

=head1 COPYRIGHT

Copyright (c) 2001-2003 dimedis GmbH, All Rights Reserved

=head1 SEE ALSO

dddl, Dimedis::Ddl::Config, Dimedis::Sql

=cut
