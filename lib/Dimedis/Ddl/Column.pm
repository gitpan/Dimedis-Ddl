package Dimedis::Ddl::Column;

use Carp;
use strict;
use FileHandle;

my %known_data_types = (
	'serial'      => 1,
	'date'        => 1,
	'native_date' => 1,
	'clob'        => 1,
	'blob'        => 1,
	'varchar'     => 1,
	'char'        => 1,
	'integer'     => 1,
	'numeric'     => 1,
);

sub get_table			{ shift->{table}			}
sub get_config_value		{ shift->{config_value}			}
sub get_name			{ shift->{name}				}
sub get_type			{ shift->{type}				}
sub get_full_type		{ shift->{full_type}			}
sub get_not_null		{ shift->{not_null}			}
sub get_null			{ shift->{null}				}
sub get_null_keep		{ shift->{null_keep}			}
sub get_null_alter		{ shift->{null_alter}			}
sub get_default			{ shift->{default}			}
sub get_like_search		{ shift->{like_search}			}
sub get_case_sensitive		{ shift->{case_sensitive}		}
sub get_comment			{ shift->{comment}			}
sub get_alter_state		{ shift->{alter_state}			}
sub get_ddl_object		{ shift->get_table->get_ddl_object	}
sub add_error			{ shift->get_ddl_object->add_error(@_)	}


sub new_from_config {
	my $class = shift;
	my %par = @_;
	my  ($name, $config_value, $table, $alter_state) =
	@par{'name','config_value','table','alter_state'};
	
	$name = lc($name);
	
	my $self = bless {
		table        => $table,
		name	     => $name,
		config_value => $config_value,
		alter_state  => $alter_state,
		full_type    => undef,
		type         => undef,
		not_null     => undef,
		null	     => undef,
		null_keep    => undef,
		null_alter   => undef,
		like_search  => undef,
		default      => undef,
		comment      => undef,
	}, $class;

	$self->parse_config_value;

	return $self;
}

sub parse_config_value {
	my $self = shift;
	
	my $config_value = lc($self->get_config_value);
	
	my ($full_type, $type, $null, $not_null, $default,
	    $comment, $like_search, $null_keep, $null_alter,
	    $case_sensitive);

	$full_type = $1 if $config_value =~ s/^(\S+\s*(\(\d+\))?)//;
	($type) = $full_type =~ /^(\w+)/;

	return $self->add_error (
		table   => $self->get_table->get_name,
		column  => $self->get_name,
		message => "Unknown column type '$type'"
	) if not defined $known_data_types{$type};

	$full_type = "char(16)" if $type eq 'date';
	
	$null_alter     = 1  if $config_value =~ s/alter//i;
	$null_keep      = 1  if $config_value =~ s/keep//i;
	$not_null       = 1  if $config_value =~ s/(not\s+null)//i;
	$null           = 1  if $config_value =~ s/(null)//i;
	$like_search    = 1  if $config_value =~ s/like[_\s]+search//i;
	$case_sensitive = 1  if $config_value =~ s/case[_\s]+sensitive//i;
	$default        = $1 if $config_value =~ s/default\s+('[^']+')//;
	$default        = $1 if $config_value =~ s/default\s+([^\s]+)//;
	$comment        = $1 if $config_value =~ s/--(.*)//;
	$comment        =~ s/\s+$//;

	$config_value =~ s/^\s+//;
	$config_value =~ s/\s+$//;

	return $self->add_error (
		table   => $self->get_table->get_name,
		column  => $self->get_name,
		message => "You must specify NULL/NOT NULL constraint in ".
	    		   "combination with either KEEP or ALTER"
	) if $self->get_alter_state eq 'modify' and
	     $type ne 'serial' and
	     ( not ($null_keep xor $null_alter) or
	       not ($null xor $not_null) );

	return $self->add_error (
		table   => $self->get_table->get_name,
		column  => $self->get_name,
		message => "KEEP and ALTER only allowed in modify mode"
	) if $self->get_alter_state ne 'modify' and
	     ($null_keep or $null_alter);

	return $self->add_error (
		table   => $self->get_table->get_name,
		column  => $self->get_name,
		message => "Unknown keywords in column definition: '$config_value'"
	) if $config_value;
	
	return $self->add_error (
		table   => $self->get_table->get_name,
		column  => $self->get_name,
		message => "Data type SERIAL is NOT NULL implicitly"
	) if $type eq 'serial' and ( $not_null or $null );
	
	if ( $type eq 'serial' ) {
		$not_null   = 1;
		$null_keep  = 1;
		$null_alter = 0;
	}

	$full_type = uc($full_type);
	$full_type =~ s/^\s+//;
	$full_type =~ s/\s+$//;

	$self->{full_type}      = $full_type;
	$self->{type} 	        = $type;
	$self->{null}           = $null;   
	$self->{not_null}       = $not_null;
	$self->{null_keep}      = $null_keep;
	$self->{null_alter}     = $null_alter;
	$self->{default}        = $default;
	$self->{comment}        = $comment;
	$self->{like_search}    = $like_search;
	$self->{case_sensitive} = $case_sensitive;
	
	1;
}

sub get_comment_ddl {
	my $self = shift;

	return "" if not $self->get_comment;
	return "-- ".$self->get_comment;
}

sub has_index {
	my $self = shift;
	
	my $indices = $self->get_table->get_indices;

	my $name = $self->get_name;

	foreach my $index ( @{$indices} ) {
		return 1 if $index->get_on =~ /\b$name\b/;
	}
	
	return;
}

sub get_alter_add_ddl {
	my $self = shift;
	
	my $sql = "ALTER TABLE ".$self->get_table->get_name.
		  " ADD ".$self->get_ddl;
	$sql =~ s/\s+/ /g;
	
	return $sql;
}

sub get_alter_drop_ddl {
	my $self = shift;
	
	my $sql = "ALTER TABLE ".$self->get_table->get_name.
		  " DROP COLUMN ".$self->get_name;
	$sql =~ s/\s+/ /g;
	
	return $sql;
}

sub get_alter_modify_ddl {
	my $self = shift;
	
	my $sql = "ALTER TABLE ".$self->get_table->get_name.
		   " MODIFY ".$self->get_ddl;

	$sql =~ s/\s+/ /g;
	
	return $sql;
}

1;
