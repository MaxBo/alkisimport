\set ON_ERROR_STOP

CREATE OR REPLACE FUNCTION alkis_checkflurstueck() RETURNS VARCHAR AS $$
DECLARE
	invalid INTEGER;
BEGIN
	BEGIN
		SELECT count(*) INTO invalid FROM ax_flurstueck WHERE NOT st_isvalid(wkb_geometry);
	EXCEPTION
		WHEN OTHERS THEN
			BEGIN
				UPDATE ax_flurstueck SET wkb_geometry=st_makevalid(wkb_geometry) WHERE NOT st_isvalid(wkb_geometry);
				SELECT count(*) INTO invalid FROM ax_flurstueck WHERE NOT st_isvalid(wkb_geometry);
			EXCEPTION
				WHEN OTHERS THEN
					RAISE EXCEPTION 'Erneute Validierungsausnahme bei ax_flurstueck.';
			END;
	END;

	IF invalid > 0 THEN
		RAISE EXCEPTION '% ungültige Geometrien in ax_flurstueck', invalid;
	END IF;

	RETURN 'ax_flurstueck geprüft.';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION alkis_createnutzung() RETURNS varchar AS $$
DECLARE
        r  RECORD;
	nv VARCHAR;
	kv VARCHAR;
	d  VARCHAR;
        f  VARCHAR;
        n  VARCHAR;
        i  INTEGER;
	invalid INTEGER;
BEGIN
	nv := E'CREATE VIEW ax_tatsaechlichenutzung AS\n  ';
	kv := E'CREATE VIEW ax_tatsaechlichenutzungsschluessel AS\n  ';
	d := '';

        -- In allen Tabellen die Objekte Löschen, die ein Ende-Datum haben
        i := 0;
        FOR r IN
                SELECT
			name,
			kennung
                FROM alkis_elemente
                WHERE 'ax_tatsaechlichenutzung' = ANY (abgeleitet_aus)
        LOOP
		BEGIN
			EXECUTE 'SELECT count(*) FROM '||r.name||' WHERE NOT st_isvalid(wkb_geometry)' INTO invalid;
		EXCEPTION
			WHEN OTHERS THEN
				BEGIN
					EXECUTE 'UPDATE '||r.name||' SET wkb_geometry=st_makevalid(wkb_geometry) WHERE NOT st_isvalid(wkb_geometry)';
					EXECUTE 'SELECT count(*) FROM '||r.name||' WHERE NOT st_isvalid(wkb_geometry)' INTO invalid;
				EXCEPTION
					WHEN OTHERS THEN
						RAISE EXCEPTION 'Erneute Validierungsausnahme in %', r.name;
				END;
		END;

		IF invalid > 0 THEN
			RAISE EXCEPTION '% ungültige Geometrien in %', invalid, r.name;
		END IF;

		f := CASE r.name
		     WHEN 'ax_halde'					THEN 'NULL'
		     WHEN 'ax_bergbaubetrieb'				THEN 'NULL'
		     WHEN 'ax_heide'					THEN 'NULL'
		     WHEN 'ax_moor'					THEN 'NULL'
		     WHEN 'ax_sumpf'					THEN 'NULL'
		     WHEN 'ax_wohnbauflaeche'				THEN 'artderbebauung'
		     WHEN 'ax_industrieundgewerbeflaeche'		THEN 'funktion'
		     WHEN 'ax_tagebaugrubesteinbruch'			THEN 'abbaugut'
		     WHEN 'ax_flaechegemischternutzung'			THEN 'funktion'
		     WHEN 'ax_flaechebesondererfunktionalerpraegung'	THEN 'funktion'
		     WHEN 'ax_sportfreizeitunderholungsflaeche'		THEN 'funktion'
		     WHEN 'ax_friedhof'					THEN 'funktion'
		     WHEN 'ax_strassenverkehr'				THEN 'funktion'
		     WHEN 'ax_weg'					THEN 'funktion'
		     WHEN 'ax_platz'					THEN 'funktion'
		     WHEN 'ax_bahnverkehr'				THEN 'funktion'
		     WHEN 'ax_flugverkehr'				THEN 'funktion'
		     WHEN 'ax_schiffsverkehr'				THEN 'funktion'
		     WHEN 'ax_gehoelz'					THEN 'funktion'
		     WHEN 'ax_unlandvegetationsloseflaeche'		THEN 'funktion'
		     WHEN 'ax_fliessgewaesser'				THEN 'funktion'
		     WHEN 'ax_hafenbecken'				THEN 'funktion'
		     WHEN 'ax_stehendesgewaesser'			THEN 'funktion'
		     WHEN 'ax_meer'					THEN 'funktion'
		     WHEN 'ax_landwirtschaft'				THEN 'vegetationsmerkmal'
		     WHEN 'ax_wald'					THEN 'vegetationsmerkmal'
		     ELSE NULL
		     END;
		IF f IS NULL THEN
			RAISE EXCEPTION 'Unerwartete Nutzungstabelle %', r.name;
		END IF;

		n := CASE r.name
		     WHEN 'ax_halde'					THEN 'Halde'
		     WHEN 'ax_bergbaubetrieb'				THEN 'Bergbaubetrieb'
		     WHEN 'ax_heide'					THEN 'Heide'
		     WHEN 'ax_moor'					THEN 'Moor'
		     WHEN 'ax_sumpf'					THEN 'Sumpf'
		     WHEN 'ax_wohnbauflaeche'				THEN 'Wohnbaufläche'
		     WHEN 'ax_industrieundgewerbeflaeche'		THEN 'Industrie- und Gewerbefläche'
		     WHEN 'ax_tagebaugrubesteinbruch'			THEN 'Tagebau, Grube, Steinbruch'
		     WHEN 'ax_flaechegemischternutzung'			THEN 'Fläche gemischter Nutzung'
		     WHEN 'ax_flaechebesondererfunktionalerpraegung'	THEN 'Fläche besonderer funktiononaler Prägung'
		     WHEN 'ax_sportfreizeitunderholungsflaeche'		THEN 'Sport-, Freizeit- und Erholungsfläche'
		     WHEN 'ax_friedhof'					THEN 'Friedhof'
		     WHEN 'ax_strassenverkehr'				THEN 'Straßenverkehr'
		     WHEN 'ax_weg'					THEN 'Weg'
		     WHEN 'ax_platz'					THEN 'Platz'
		     WHEN 'ax_bahnverkehr'				THEN 'Bahrverkehr'
		     WHEN 'ax_flugverkehr'				THEN 'Flugverkehr'
		     WHEN 'ax_schiffsverkehr'				THEN 'Schiffsverkehr'
		     WHEN 'ax_gehoelz'					THEN 'Gehölz'
		     WHEN 'ax_unlandvegetationsloseflaeche'		THEN 'Unland, vegetationslose Fläche'
		     WHEN 'ax_fliessgewaesser'				THEN 'Fließgewässer'
		     WHEN 'ax_hafenbecken'				THEN 'Hafenbecken'
		     WHEN 'ax_stehendesgewaesser'			THEN 'Stehendes Gewässer'
		     WHEN 'ax_meer'					THEN 'Meer'
		     WHEN 'ax_landwirtschaft'				THEN 'Landwirtschaft'
		     WHEN 'ax_wald'					THEN 'Wald'
		     ELSE NULL
		     END;

		IF n IS NULL THEN
			RAISE EXCEPTION 'Unerwartete Nutzungstabelle %', r.name;
		END IF;

		nv := nv
                   || d
                   || 'SELECT '
                   || 'ogc_fid*32+' || i ||' AS ogc_fid,'
		   || '''' || r.name    || '''::text AS name,'
                   || r.kennung::int || ' AS kennung,'
                   || f || '::text AS funktion,'
                   || ''''||r.kennung|| '''||coalesce('':''||'||f||','''')::text AS nutzung,'
                   || 'wkb_geometry'
		   || ' FROM ' || r.name
		   || ' WHERE endet IS NULL'
		   ;

		kv := kv
		   || d
		   || 'SELECT '''||r.kennung||''' AS nutzung,'''||n||''' AS name'
		   ;

		IF f<>'NULL' THEN
			kv := kv
			   || ' UNION SELECT '''
			   || r.kennung||':''||k AS nutzung,v AS name'
			   || '  FROM alkis_wertearten WHERE element=''' || r.name || ''' AND bezeichnung=''' || f || ''''
			   ;
		END IF;

		d := E' UNION\n  ';
		i := i + 1;
        END LOOP;

	PERFORM alkis_dropobject('ax_tatsaechlichenutzung');
	EXECUTE nv;

	PERFORM alkis_dropobject('ax_tatsaechlichenutzungsschluessel');
	EXECUTE kv;

	RETURN 'ax_tatsaechlichenutzung und ax_tatsaechlichenutzungsschluessel erzeugt.';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION alkis_createklassifizierung() RETURNS varchar AS $$
DECLARE
        r  RECORD;
	nv VARCHAR;
	kv VARCHAR;
	d  VARCHAR;
        f  VARCHAR;
        p  VARCHAR;
	i  INTEGER;
	invalid INTEGER;
BEGIN
	nv := E'CREATE VIEW ax_klassifizierung AS\n  ';
	kv := E'CREATE VIEW ax_klassifizierungsschluessel AS\n  ';
	d := '';

        -- In allen Tabellen die Objekte Löschen, die ein Ende-Datum haben
	i := 0;
        FOR r IN
                SELECT
			name,
			kennung
                FROM alkis_elemente
                WHERE name IN ('ax_bewertung','ax_klassifizierungnachwasserrecht','ax_klassifizierungnachstrassenrecht')
        LOOP
		BEGIN
			EXECUTE 'SELECT count(*) FROM '||r.name||' WHERE NOT st_isvalid(wkb_geometry)' INTO invalid;
		EXCEPTION
			WHEN OTHERS THEN
				BEGIN
					EXECUTE 'UPDATE '||r.name||' SET wkb_geometry=st_makevalid(wkb_geometry) WHERE NOT st_isvalid(wkb_geometry)';
					EXECUTE 'SELECT count(*) FROM '||r.name||' WHERE NOT st_isvalid(wkb_geometry)' INTO invalid;
				EXCEPTION
					WHEN OTHERS THEN RAISE EXCEPTION 'Validierungsausnahme in %', r.name;
				END;
		END;

		IF invalid > 0 THEN
			RAISE EXCEPTION '% ungültige Geometrien in %', invalid, r.name;
		END IF;

	        f := CASE r.name
		     WHEN 'ax_bewertung' THEN 'B'
		     WHEN 'ax_klassifizierungnachwasserrecht' THEN 'W'
		     WHEN 'ax_klassifizierungnachstrassenrecht' THEN 'S'
		     ELSE NULL
		     END;
		IF f IS NULL THEN
			RAISE EXCEPTION 'Unerwartete Tabelle %', r.name;
		END IF;

		p := CASE
		     WHEN r.name = 'ax_bewertung' THEN 'klassifizierung'
		     ELSE 'artderfestlegung'
		     END;

		nv := nv
                   || d
                   || 'SELECT '
                   || 'ogc_fid*4+' || i || ' AS ogc_fid,'
		   || '''' || r.name    || '''::text AS name,'
                   || r.kennung::int || ' AS kennung,'
                   || p || ' AS artderfestlegung,'
                   || ''''||f||':''||'||p||' AS klassifizierung,'
                   || 'wkb_geometry'
		   || ' FROM ' || r.name
		   || ' WHERE endet IS NULL'
		   ;

		kv := kv
		   || d
		   || 'SELECT '
		   || '''' || f || ':''||k AS klassifizierung,v AS name'
		   || '  FROM alkis_wertearten WHERE element=''' || r.name || ''' AND bezeichnung='''||p||''''
		   ;

		d := E' UNION\n  ';
		i := i + 1;
        END LOOP;

	PERFORM alkis_dropobject('ax_klassifizierung');
	EXECUTE nv;

	PERFORM alkis_dropobject('ax_klassifizierungsschluessel');
	EXECUTE kv;

	RETURN 'ax_klassifizierung und ax_klassifizierungsschluessel erzeugt.';
END;
$$ LANGUAGE plpgsql;

SELECT 'Prüfe Flurstücksgeometrien...';
SELECT alkis_checkflurstueck();

SELECT 'Prüfe Klassifizierungen...';
SELECT alkis_createklassifizierung();

SELECT 'Prüfe tatsächliche Nutzungen...';
SELECT alkis_createnutzung();

DELETE FROM kls_shl;
INSERT INTO kls_shl(klf,klf_text)
  SELECT klassifizierung,name FROM ax_klassifizierungsschluessel;

DELETE FROM nutz_shl;
INSERT INTO nutz_shl(nutzshl,nutzung)
  SELECT nutzung,name FROM ax_tatsaechlichenutzungsschluessel;

SELECT alkis_dropobject('klas_3x_pk_seq');
CREATE SEQUENCE klas_3x_pk_seq;

SELECT 'Erzeuge Flurstücksklassifizierungen...';

DELETE FROM klas_3x;
INSERT INTO klas_3x(flsnr,pk,klf,fl,ff_entst,ff_stand)
  SELECT
    to_char(f.land,'fm00') || to_char(f.gemarkungsnummer,'fm0000') || '-' || to_char(f.flurnummer,'fm000') || '-' || to_char(f.zaehler,'fm00000') || '/' || to_char(coalesce(f.nenner,0),'fm000') AS flsnr,
    to_hex(nextval('klas_3x_pk_seq'::regclass)) AS pk,
    k.klassifizierung AS klf,
    sum(st_area(st_intersection(f.wkb_geometry,k.wkb_geometry)))::int AS fl,
    0 AS ff_entst,
    0 AS ff_stand
  FROM ax_flurstueck f
  JOIN ax_klassifizierung k ON f.wkb_geometry && k.wkb_geometry AND st_intersects(f.wkb_geometry,k.wkb_geometry)
  WHERE f.endet IS NULL AND st_area(st_intersection(f.wkb_geometry,k.wkb_geometry))::int>0
  GROUP BY
    f.land, f.gemarkungsnummer, f.flurnummer, f.zaehler, coalesce(f.nenner,0), k.klassifizierung;

SELECT alkis_dropobject('nutz_shl_pk_seq');
CREATE SEQUENCE nutz_shl_pk_seq;

SELECT 'Erzeuge Flurstücksnutzungen...';

DELETE FROM nutz_21;
INSERT INTO nutz_21(flsnr,pk,nutzsl,fl,ff_entst,ff_stand)
  SELECT
    to_char(f.land,'fm00') || to_char(f.gemarkungsnummer,'fm0000') || '-' || to_char(f.flurnummer,'fm000') || '-' || to_char(f.zaehler,'fm00000') || '/' || to_char(coalesce(f.nenner,0),'fm000') AS flsnr,
    to_hex(nextval('nutz_shl_pk_seq'::regclass)) AS pk,
    n.nutzung AS nutzsl,
    sum(st_area(st_intersection(f.wkb_geometry,n.wkb_geometry)))::int AS fl,
    0 AS ff_entst,
    0 AS ff_stand
  FROM ax_flurstueck f
  JOIN ax_tatsaechlichenutzung n ON f.wkb_geometry && n.wkb_geometry AND st_intersects(f.wkb_geometry,n.wkb_geometry)
  WHERE f.endet IS NULL AND st_area(st_intersection(f.wkb_geometry,n.wkb_geometry))::int>0
  GROUP BY f.land, f.gemarkungsnummer, f.flurnummer, f.zaehler, coalesce(f.nenner,0), n.nutzung;

-- TODO: Wo sind denn den ausführenden Stellen in ALKIS?