package Dimedis::Ddl::PrimaryKey;

use Carp;
use strict;

sub get_on			{ shift->{on}				}
sub get_name			{ shift->{name}				}
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
		on     => $config_value->{on},
		name   => $config_value->{name},
		table  => $table,
		alter_state  => $alter_state,
	}, $class;

	my $err = 0;

	$self->add_error (
		table   => $table->get_name,
		message => "Primary Key attribute 'name' not set"
	), $err = 1 if $config_value->{name} eq '';

	$self->add_error (
		table   => $table->get_name,
		message => "Primary Key attribute 'on' not set"
	), $err = 1 if $config_value->{on} eq '';

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
