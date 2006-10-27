package Dimedis::Ddl::Config;

use Carp;
use strict;
use FileHandle;

sub get_data			{ shift->{data}				}
sub set_data			{ shift->{data}			= $_[1]	}

sub get_filename		{ shift->{filename}			}
sub get_dir			{ shift->{dir}				}

sub new {
	my $class = shift;
	my %par = @_;
	my  ($data) =
	@par{'data'};
	
	croak "data is not an array reference"
		if defined $data and ref $data ne 'ARRAY';
	
	$data ||= [];
	
	my $self = {
		data     => $data,
		filename => undef,
		dir      => undef,
	};
	
	return bless $self, $class;
}

sub add_file {
	my $self = shift;
	my %par = @_;
	my ($filename) = @par{'filename'};
	
	# Read content of file
	my $content;
	my $fh = FileHandle->new;
	open ($fh, $filename) or croak "can't read '$filename'";
	$content .= $_ while <$fh>;
	close $fh;
	
	# Catch STDERR, because "use strict" violations are not added to $@
	open (ORIG_STDERR, ">&STDERR")
		or die "can't dup STDERR";
	open (FETCH_STDERR, "+>/tmp/dddl-config-stderr.$$")
		or die "can't write /tmp/dddl-config-stderr.$$";
	unlink ("/tmp/dddl-config-stderr.$$");
	open (STDERR, ">&FETCH_STDERR")
		or die "can't dup STDERR to FETCH_STDERR: $!";
	
	# Eval data
	my $data = eval $content;
	my $eval_err = $@;
	
	# Restore STDERR and read fetched data
	open (STDERR, ">&ORIG_STDERR");
	seek FETCH_STDERR, 0, 0;
	my $fetch_stderr = join ('', <FETCH_STDERR>);
	close FETCH_STDERR;
	
	# Throw exception if something went wrong
	croak "Can't eval content of file '$filename': $eval_err $fetch_stderr"
		if $eval_err or $fetch_stderr or not ref $data eq 'ARRAY';
	
	push @{$self->get_data}, @{$data};

	1;
}

sub add_directory {
	my $self = shift;
	my %par = @_;
	my ($dir, $filter_regex) = @par{'dir','filter_regex'};
	
	my @files = grep { -f } grep !/^\.\.?$/, glob "$dir/*";
	
	@files = grep /$filter_regex/, @files if $filter_regex;

	foreach my $file ( @files ) {
		$self->add_file ( filename => $file );
	}
	
	1;
}

1;

__END__

=head1 NAME

Dimedis::Ddl::Config - Konfiguration von Dimedis::Ddl

=head1 SYNOPSIS

Diese Dokumentation beschreibt die Datenstruktur, aus der
Dimedis::Ddl den DDL Code zur Generierung von Datenbanken
erzeugt.

=head1 DESCRIPTION

Ausgangsbasis ist eine Konfigurationsdatei bzw. eine Perl Datenstruktur,
die üblicherweise in einer Konfigurationsdatei steht.

Diese Struktur definiert das Datenmodell zum Anlegen von Tabellen,
Indices, Constraints und Fremdschlüsselreferenzen. Weiterhin können
damit Änderungen an o.g. Datenbankobjekten beschrieben werden (ALTER
TABLE). Hinweise dazu gibt es in einem eigenen Kapitel.

=head2 Grundstruktur

Die Konfigurations-Datenstruktur ist eine Listenreferenz. Für jede
Tabelle gibt es zwei Einträge: den Namen sowie eine weitere Liste
mit den Eigenschaften der Tabelle:

  [
    table_a => [
      ...
    ],
    table_b => [
      ...
    ],
    ...
  ]

Die => Schreibweise suggeriert zwar ein Hash, es handelt sich aber
um Listenreferenzen, da ein Hash die Reihenfolge der Elemente nicht
erhalten würde.

Der Inhalt einer Tabellendefinition ist wiederum ein als Listenreferenz
aufgeschriebenes Hash und definiert die Spalten der Tabelle, sowie
Constraints, Indices etc.

=head1 KONFIGURATION ZUM ANLEGEN VON OBJEKTEN

Zunächst folgt eine Beschreibung zum Anlegen von neuen Objekten
in der Datenbank. Das darauf folgende Kapitel beschreibt die Änderung
von existierenden Objekten, wobei dabei aber letztlich dieselbe
Syntax, erweitert um wenige Schlüsselworte, Verwendung findet.

B<Wichtig:>

Spaltendefinitionen müssen beim Anlegen von Tabellen immer zuerst
genannt werden, erst danach dürfen Primärschlüssel, Constraints
etc. definiert werden. Ansonsten bricht Dimedis::Ddl mit einer
Fehlermeldung ab: "missing _alter option or wrong order (specify
columns first)".

=head2 Definition von Spalten

Spalten werden einfach durch ihren Namen und Typen definiert, wobei
für die Typbeschreibung eine reduzierte DDL Syntax zur Verfügung steht.

B<Beispiel:>

  it_lang => [
    ni_id          => "SERIAL",
    ns_name        => "VARCHAR(30)",
    ns_iconpath    => "VARCHAR(255) NOT NULL",
    ni_default     => "NUMERIC(1) DEFAULT 0 NOT NULL",
    ns_shortcut    => "VARCHAR(4)",
  ],

Spaltennamen dürfen nicht mit einem Unterstrich anfangen, weil
solche Bezeichner für die Definition von Primärschlüsseln, Constraints
etc. reserviert sind. Mehr dazu weiter unten.

Folgende Spaltentypen stehen zur Verfügung:

  SERIAL          automatisch generierter numerischer Schlüssel
  		  (per Default NOT NULL, die Angabe von NULL/NOT NULL
		   ist nicht erlaubt)
  VARCHAR(n)      alphanumerisch mit max. n Zeichen
  CHAR(n)         alphanumerisch mit exakt n Zeichen
  INTEGER         32 Bit Integer Zahl
  NUMERIC(n[,m])  numerischer Wert mit n Stellen, davon m
                  nach dem Komma
  BLOB            Binary large object
  CLOB            Character large object
  DATE            Dimedis::Sql Datumsfeld (16 Zeichen CHAR)
  NATIVE_DATE     Datumsfeld, datenbankspezifisch. Sollte nur
                  in Ausnahmefällen verwendet werden, da Dimedis::Sql
                  es nicht unterstützt

Groß-/Kleinschreibung ist bei den Typen nicht relevant, per Konvention
sollte aber Großschreibung verwendet werden.

=head2 Optionen bei der Spaltendefinition

Hinter dem Spaltentyp können mit Leerzeichen getrennt in beliebiger
Reihenfolge folgende Optionen angegeben werden:

  NULL		  Spalte darf NULL werden (Default)
  NOT NULL        Spalte darf nicht NULL werden
  DEFAULT '...'   String als Defaultwert
  DEFAULT n       Zahl als Defaultwert
  DEFAULT SYSDATE Wenn die Datenbank es unterstützt, wird hier
                  das aktuelle Datum eingesetzt
  LIKE SEARCH     Gibt für ein VARCHAR Feld an, daß es LIKE
                  Suchen unterstützen muß
  CASE SENSITIVE  Wirkt sich derzeit nur bei MySQL aus. Die
  		  Spalte wird mit der BINARY Option angelegt.
		  D.h. die Sortierung erfolgt per ASCII (Umlaute
		  werden falsch einsortiert), dafür werden Indices,
		  Unique Constraints aber case sensitive.

Weitere Optionen werden nicht unterstützt. NULL bzw. NOT NULL können
beide weggelassen werden, dann ist die Spalte per Default NULL
definiert. NULL muß also i.d.R. nicht angegeben werden, ist aber
bei ALTER TABLE Verwendung nötig, wenn eine Spalte explizit zu NULL
werden soll (siehe "Konfiguration zum Ändern von Objekten").

Die LIKE_SEARCH Option ist ein Hinweis für Datenbanken, die Einschränkungen
bei großen VARCHAR Feldern haben und muß bei allen Spalten gesetzt
werden, über die später LIKE Suchen gemacht werden.

=head2 Definition des Primärschlüssels

Der Primärschlüssel der Tabelle wird mit dem B<_primary_key>
Schlüsselwort festgelegt:

B<Beispiel:>

  it_lang => [
    ni_id        => "SERIAL",
    ns_name      => "VARCHAR(30)",
    _primary_key => [
      on         => "ni_id",
      name       => "pk_it_lang",
    ],
  ],

B<_primary_key> ist also ein Hash (das auch als Liste übergbeben
werden darf) mit folgenden Schlüsseln:

  on               Name der Spalte, die Primary Key sein soll
  		   (mehrere Spalten mit Komma getrennt)
  name             Name des dazugehörigen Constraints

Beide Schlüssel müssen angegeben werden.

=head2 Definition von Fremdschlüssel Referenzen

Fremdschlüssel werden wie folgt mit B<_reference> oder
B<_references> definiert:

  it_ticket_dump => [
    ni_id            => "SERIAL",
    ns_ticket        => "VARCHAR(14)",
    _primary_key     => "ni_id",
    _reference => [
      name           => "r_ticsto_tic",
      src_col        => "ns_ticket",
      dest_table     => "it_ticket",
      dest_col       => "ns_ticket",
      delete_cascade => 0,
    ],
  ],

B<_reference> ist also ein Hash (das auch als Liste übergeben
werden darf) mit folgenden Schlüsseln:

  name             Name das dazugehörigen Constraints
  src_col          Quellspalte(n) in der aktuellen Tabelle,
                   Angabe mehrerer durch Komma getrennter
		   Spaltennamen ist möglich
  dest_table       Zieltabelle
  dest_col         Spalte(n) in der Zieltabelle,
                   Angabe mehrerer durch Komma getrennter
		   Spaltennamen ist möglich
  delete_cascade   1       mit DELETE CASCADE
 		   0       ohne DELETE CASCADE
		   cyclic  nur wenn die Datenbank zyklische
		           DELETE CASCADES erlaubt
  
Die Angabe B<cyclic> bedeutet, daß nur Datenbanken, die hier auch
zyklische Referenzen unterstützen, das DELETE CASCADE verwenden.
Andere Datenbanken legen diesen Constraint ebenfalls an, allerdings
ohne die ON DELETE CASCADE Option.

=head2 Definition von Indices

Indices werden auch direkt in der Tabellendefinition mit B<_index>
angegeben.

B<Beispiel:>

  it_ticket_dump => [
    ni_id        => "SERIAL",
    ns_ticket    => "VARCHAR(14)",
    _primary_key => "ni_id",
    _index => [
      name   => "unq_ticsto_tic",
      on     => "ns_ticket",
    ],
  ],

B<_index> ist also ein Hash (das auch als Liste übergeben werden darf)
mit folgenden Schlüsseln:

  name             Name des Index 
  on               Spalte(n), Angabe mehrerer durch Komma
  		   getrennter Spaltennamen ist möglich

=head2 Definition von Constraints

Über die Fremdschlüsselbeziehungen hinaus können Tabellen- und
Unique Constraints angelegt werden, mit dem Schlüsselwort B<_constraint>.

B<Beispiel:>

  it_lang => [
    ni_id          => "SERIAL",
    ns_name        => "VARCHAR(30)",
    ni_default     => "NUMERIC(1) DEFAULT 0 NOT NULL",
    _primary_key   => "ni_id",
    _constraint => [
      name   => "b_lang_nide",
      expr   => "ni_default IN (0,1)",
    ],
    _constraint => [
      name   => "uq_lang_name",
      unique => "ns_name",
    ],
  ],

B<_constraint> ist also ein Hash (das auch als Liste übergeben werden
darf) mit folgenden Schlüsseln:

  name             Name des Constraints
  expr             Ausdruck, der wahr sein muß
  unique           Spalte(n), die unique sein sollen, Angabe
  		   mehrerer durch Komma getrennter Spaltennamen
		   ist möglich

B<expr> und B<unique> dürfen nicht gleichzeitig angegeben werden.
Bei den Constraint Ausdrücken ist zu beachten, daß alle Datenbanken
diese unterstützen müssen.

=head2 Datenbankspezifische Angaben

Bestimmte Datenbankfunktionen werden von Dimedis::Ddl nur in Form
von datenbankspezifischen Erweiterungen unterstützt. Dabei werden
Einstellungen vorgenommen, die nur von dem Treiber der entsprechenden
Datenbank verarbeitet werden.

Diese Definitionen sind nach folgendem Schema benannt:

  _db_DATENBANK => [
    ...
  ],

wobei DATENBANK durch die jeweilige Zieldatenbank ersetzt wird.
Derzeit wird dies nur für Oracle genutzt, um tabellenübergreifende
Klauseln anzugeben:

  _db_Oracle => [
    table => "lob (nb_blob) store as (
    		storage (initial 1M next 1M pctincrease 0) 	
	        chunk 4 nocache logging
	      )"
  ],

D.h. am Ende der Tabellendefinition wird der entsprechende String
angehängt, um z.B. Storage Definitionen für Blobs vorzunehmen
(wie in obigem Beispiel).

=head2 Nur Type Hash Generierung

Mit der Definition

  _type_hash_only

wird kein DDL Code für diese Tabelle generiert, sondern lediglich
ein entsprechender Type Hash Eintrag.

=head1 KONFIGURATION ZUM ÄNDERN VON OBJEKTEN

Das Format zur Änderung von Objektdefinitionen ist mit dem
zum Anlegen identisch, ergänzend gibt es lediglich das Schlüsselwort
B<_alter>, das definiert, ob die folgenden Definitionen hinzugefügt,
geändert oder gelöscht werden sollen.

B<Beispiel:>

  it_lang => [
    _alter => "add",

    ns_foo => "VARCHAR(32) NOT NULL",

    _index => [
      name   => "lang_foo_idx",
      on     => "ns_foo",
    ],

    _alter   => "modify",
    ns_bar   => "VARCHAR(100)",
    
    _alter   => "drop",
    ns_baz   => "VARCHAR(16) NOT NULL",
    _constraint => "b_foo",
    _primary_key => [ name => 'pk_foo' ],
  ],

  it_foo => [
    _alter => "drop_table"
  ],

Im Beispiel wird also eine neue Spalte ns_foo samt Index angelegt,
die existierende ns_bar im Typ geändert. Die Spalte ns_baz sowie
der Constraint b_foo und der Primary 'pk_foo' werden gelöscht.
Weiterhin wird die Tabelle it_foo gelöscht.

Auf dieser Art und Weise können Spaltentypänderungen genauso durchgeführt
werden, wie Änderungen an Constraints, Referenzen und Indices, dabei
spielt es keine Rolle ob diese hinzugefügt, geändert oder gelöscht werden.

=head2 Hinweise zum Ändern von Spalten

Die Typangabe bei einer Spaltenänderung (_alter => "modify") führt zwei
neue Schlüsselwörter B<KEEP> und B<ALTER> ein, die sich auf den B<NULL/NOT NULL>
Constraint der Spalte beziehen. Bei einer Spaltenänderung muß B<immer>
B<NULL> bzw. B<NOT NULL> angegeben werden (es sei denn es handelt sich
um den B<SERIAL> Datentyp, dieser ist B<immer NOT NULL>), in Kombination
mit B<KEEP>, wenn die Spalte vorher denselben Zustand hatte bzw.
mit B<ALTER>, wenn sich der Zustand nun ändern soll.

Im obigen Beispiel wird also B<ns_foo> von B<NULL> zu B<NOT NULL>
geändert. Bei B<ns_bar> bleibt der B<NULL> Constraint so erhalten,
wie er vorher war.

Diese explizite Angabe ist notwendig, da einige Datenbanken eine
Wiederholung eines existierenden B<NULL/NOT NULL> Constraints
nicht erlauben und andere stets eine relative Angabe erwarten, bzw.
nur B<NULL/NOT NULL> angegeben werden darf, wenn sich der Constraint
auch tatsächlich ändern soll.

=head2 Hinweise zum Ändern von Indices, Constraints und Referenzen

Wenn hier ein B<modify> durchgeführt wird, so wird DDL Code erzeugt
zum Löschen und neu Anlegen des entsprechenden Objektes. Eine
direkte Änderung ist also nicht möglich. Dies muß berücksichtigt
werden, weil sich z.B. Referenzen nicht unbedingt löschen lassen,
wenn noch Daten existieren, die diese verwenden.

=head2 Hinweise zum Löschen von Indices, Constraints und Referenzen

Wenn ein Index oder Constraint gelöscht werden sollen,
so reicht es bei dem entsprechenden Hash nur den B<name> Schlüssel
anzugeben. Alle anderen Schlüssel werden in diesem Fall nicht benötigt
und ignoriert.

Bei B<Referenzen> hingegen, ist stets die vollständige Angabe
aller Parmeter erforderlich.

=head2 Hinweise zum Löschen von Tabellen

Eine Tabelle wird mit der Anweisung B<_alter =E<gt> "drop_table">
gelöscht. In diesem Fall dürfen keine anderen Angaben innerhalb dieser
Tabellendefinition gemacht werden.

=head2 Mischung von Änderungs- und Erstellungs-Definitionen

Innerhalb einer DDL Konfiguration dürfen sowohl Änderungsdefinitionen
als auch solche zum Erstellen gemischt werden. Sobald das Schlüsselwort
B<_alter> in einer Tabellenkonfiguration gefunden wird, werden alle
folgenden Definitionen als Änderungen aufgefaßt. Wird das Schlüsselwort
nicht verwendet, so handelt wird die entsprechende Tabelle inkl.
angegebener Indices etc. neu angelegt.

=head2 Sonderfall: Löschen eines SERIAL Primary Key Constraints

Ein Primary Key Constraint auf einem SERIAL kann nicht einfach wie
folgt gelöscht werden:

  it_foo => [
    _alter       => 'drop',
    _primary_key => [ name => 'pk_foo' ]
  ]

Dies wird von MySQL nicht unterstützt. Zunächst muß eine normale,
nicht-SERIAL Spalte daraus gemacht werden, erst danach darf der
Primary Key Constrint entfernt werden. Richtig ist also:

  it_foo => [
    _alter       => 'modify',
    ni_id        => 'integer keep not null',

    _alter       => 'drop',
    _primary_key => [ name => 'pk_foo' ]
  ]

Damit funktioniert es mit allen Datenbanken.

=head1 AUTOR

Joern Reder <joern@dimedis.de>

=head1 COPYRIGHT

Copyright (c) 2001-2003 dimedis GmbH, All Rights Reserved

=head1 SEE ALSO

dddl, Dimedis::Ddl, Dimedis::Sql

=cut
