package Dimedis::Ddl::Constraint;

use Carp;
use strict;

sub get_name			{ shift->{name}				}
sub get_expr			{ shift->{expr}				}
sub get_unique			{ shift->{unique}			}
sub get_table			{ shift->{table}			}
sub get_alter_state		{ shift->{alter_state}			}
sub get_ddl_object		{ shift->get_table->get_ddl_object	}
sub add_error			{ shift->get_ddl_object->add_error(@_)	}

sub new_from_config {
	my $class = shift;
	my %par = @_;
	my  ($table, $config_value, $alter_state) =
	@par{'table','config_value','alter_state'};
	
	my $self = bless {
		name   => $config_value->{name},
		expr   => $config_value->{expr},
		unique => $config_value->{unique},
		table  => $table,
		alter_state  => $alter_state,
	}, $class;

	my $err = 0;

	$self->add_error (
		table   => $table->get_name,
		message => "Constraint attribute 'name' not set"
	), $err = 1 if $config_value->{name} eq '';

	$self->add_error (
		table   => $table->get_name,
		message => "Constraint: $config_value->{name} either ".
			   "'expr' or 'unique' must be set"
	), $err = 1 if $alter_state eq 'create' and not
		       ($config_value->{expr} ne '' xor
		        $config_value->{unique} ne '');

	return if $err;
	return $self;
}

sub get_alter_add_ddl {
	my $self = shift;
	return $self->get_create_ddl;
}

sub get_alter_drop_ddl {
	my $self = shift;
	return $self->get_drop_ddl;
}

sub get_alter_modify_ddl {
	my $self = shift;
	
	return (
		$self->get_alter_drop_ddl,
		$self->get_alter_add_ddl
	);
}

1;
