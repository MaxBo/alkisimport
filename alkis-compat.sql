CREATE FUNCTION unnest(anyarray) RETURNS SETOF anyelement AS $$
  SELECT $1[i] FROM generate_series(array_lower($1,1), array_upper($1,1)) i;
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_geomfromtext(text,integer) RETURNS geometry AS $$
  SELECT geomfromtext($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_multi(geometry) RETURNS geometry AS $$
  SELECT multi($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_intersection(geometry,geometry) RETURNS geometry AS $$
  SELECT intersection($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_intersects(geometry,geometry) RETURNS BOOLEAN AS $$
  SELECT intersects($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_isvalid(geometry) RETURNS BOOLEAN AS $$
  SELECT isvalid($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_buffer(geometry,float8) RETURNS geometry AS $$
  SELECT buffer($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_area(geometry) RETURNS float8 AS $$
  SELECT area($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_centroid(geometry) RETURNS geometry AS $$
  SELECT centroid($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_translate(geometry,float8,float8) RETURNS geometry AS $$
  SELECT translate($1,$2,$3);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_makeline(geometry,geometry) RETURNS geometry AS $$
  SELECT makeline($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_line_interpolate_point(geometry,float8) RETURNS geometry AS $$
  SELECT line_interpolate_point($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_reverse(geometry) RETURNS geometry AS $$
  SELECT reverse($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_length(geometry) RETURNS float8 AS $$
  SELECT length($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_force_2d(geometry) RETURNS geometry AS $$
  SELECT force_2d($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_srid(geometry) RETURNS integer AS $$
  SELECT srid($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_setsrid(geometry,integer) RETURNS geometry AS $$
  SELECT setsrid($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_geometryn(geometry,integer) RETURNS geometry AS $$
  SELECT geometryn($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_pointn(geometry,integer) RETURNS geometry AS $$
  SELECT pointn($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_point(float8, float8) RETURNS geometry AS $$
  SELECT makepoint($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_azimuth(geometry, geometry) RETURNS float8 AS $$
  SELECT azimuth($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_rotate(geometry, float8) RETURNS geometry AS $$
  SELECT rotate($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_x(geometry) RETURNS float8 AS $$
  SELECT x($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_y(geometry) RETURNS float8 AS $$
  SELECT y($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_collect(geometry,geometry) RETURNS geometry AS $$
  SELECT collect($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_linemerge(geometry) RETURNS geometry AS $$
  SELECT linemerge($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_dump(geometry) RETURNS SETOF geometry_dump AS $$
  SELECT dump($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION st_makevalid(geometry) RETURNS geometry AS $$
  SELECT buffer($1,0);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE AGGREGATE st_collect (
        sfunc = geom_accum,
	basetype = geometry,
	stype = geometry[],
	finalfunc = collect_garray
);

CREATE FUNCTION alkis_intersect_lines( p0 geometry, p1 geometry, p2 geometry, p3 geometry ) RETURNS geometry AS $$
DECLARE
	d float8;
	dx float8;
	dy float8;
	vx float8;
	vy float8;
	wx float8;
	wy float8;
	k float8;
BEGIN
	vx := st_x(p1)-st_x(p0);
	vy := st_y(p1)-st_y(p0);
	
	wx := st_x(p3)-st_x(p2);
	wy := st_y(p3)-st_y(p2);

	d := vy*wx-vx*wy;

	IF d=0 THEN
		RETURN NULL;
	END IF;

	dx := st_x(p2)-st_x(p0);
	dy := st_y(p2)-st_y(p0);
	
	k := (dy*wx-dx*wy)/d;
	
	RETURN st_translate( p0, k*vx, k*vy );
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION st_offsetcurve(g0 geometry,offs float8,params text) RETURNS geometry AS $$
DECLARE
        i INTEGER;
	n INTEGER;
	p0 GEOMETRY;
	p1 GEOMETRY;
	p2 GEOMETRY;
	p00 GEOMETRY;
	p01 GEOMETRY;
	p10 GEOMETRY;
	p11 GEOMETRY;
	d0 float8;
	d1 float8;
	dx float8;
	dy float8;
	r GEOMETRY[];
	g GEOMETRY;
BEGIN
	IF params IS NULL OR params<>'' THEN
		RAISE EXCEPTION 'st_offsetcurve: params nicht unterstützt.';
	END IF;

	IF geometrytype(g0)='MULTILINESTRING' THEN
		IF st_numgeometries(g0)<>1 THEN
			RETURN NULL;
		END IF;
		g := st_geometryn(g0,1);
	ELSIF geometrytype(g0)<>'LINESTRING' THEN
		RETURN NULL;
	ELSE
		g := g0;
	END IF;
	
	n := st_numpoints(g);
	IF n IS NULL OR n<2 THEN
		RETURN NULL;
	END IF;
	
	p2 := st_pointn(g,1);
	
	FOR i IN 2..n LOOP
		p0 := p1;
		p1 := p2;
		d0 := d1;
		
		IF i>2 THEN
			dx := (st_y(p0)-st_y(p1)) * offs / d0;
			dy := (st_x(p1)-st_x(p0)) * offs / d0;
			p00 := st_translate( p0, dx, dy );
			p01 := st_translate( p1, dx, dy );
		END IF;

		p2 := st_pointn(g,i);
		d1 := st_distance( p1, p2 );

		dx := (st_y(p1)-st_y(p2)) * offs / d1;
		dy := (st_x(p2)-st_x(p1)) * offs / d1;
	
		p10 := st_translate( p1, dx, dy );
		p11 := st_translate( p2, dx, dy );
		
		IF i=2 THEN
			r := ARRAY[ p10 ];
		ELSE
			r := array_append( r, coalesce( alkis_intersect_lines( p00, p01, p10, p11 ), p01 ) );
		END IF;
		
		IF i=n THEN
			r := array_append( r, p11 );
		END IF;
	END LOOP;

	IF o<0 THEN
		RETURN st_reverse( st_makeline(r) );
	ELSE
		RETURN st_makeline(r);
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION force_2d(geometry) RETURNS geometry AS $$
  SELECT st_force_2d($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION force_collection(geometry) RETURNS geometry AS $$
  SELECT st_force_collection($1);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION asbinary(geometry,text) RETURNS bytea AS $$
  SELECT st_asbinary($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;

CREATE FUNCTION setsrid(geometry,integer) RETURNS geometry AS $$
  SELECT st_setsrid($1,$2);
$$ LANGUAGE 'sql' IMMUTABLE;