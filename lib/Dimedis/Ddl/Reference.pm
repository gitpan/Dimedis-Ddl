package Dimedis::Ddl::Reference;

use Carp;
use strict;

sub get_name			{ shift->{name}				}
sub get_src_col			{ shift->{src_col}			}
sub get_dest_table		{ shift->{dest_table}			}
sub get_dest_col		{ shift->{dest_col}			}
sub get_delete_cascade		{ shift->{delete_cascade}		}
sub get_table			{ shift->{table}			}
sub get_alter_state		{ shift->{alter_state}			}
sub get_ddl_object		{ shift->get_table->get_ddl_object	}
sub add_error			{ shift->get_ddl_object->add_error(@_)	}

sub new_from_config {
	my $class = shift;
	my %par = @_;
	my  ($table, $config_value, $alter_state) =
	@par{'table','config_value','alter_state'};

	$config_value->{src_col}  =~ s/\s+//g;
	$config_value->{dest_col} =~ s/\s+//g;

	my $self = bless {
		name	       => $config_value->{name},
		src_col        => $config_value->{src_col},
		dest_table     => $config_value->{dest_table},
		dest_col       => $config_value->{dest_col},
		delete_cascade => $config_value->{delete_cascade},
		table          => $table,
		alter_state    => $alter_state,
	}, $class;

	my $err = 0;

	$self->add_error (
		table   => $table->get_name,
		message => "Reference attribute 'name' not set ".
			   "($config_value->{name})"
	), $err = 1 if $config_value->{name} eq '';

	foreach my $attr ( qw ( src_col dest_table dest_col
			        delete_cascade) ) {
		$self->add_error (
		    table   => $table->get_name,
		    message => "Reference attribute '$attr' not set ".
		    	       "($config_value->{name})"
		), $err = 1 if $config_value->{$attr} eq '' and
		               $attr ne 'delete_cascade';
	}

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
