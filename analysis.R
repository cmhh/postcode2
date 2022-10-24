# connect to database ----------------------------------------------------------
conn <- RPostgreSQL::dbConnect(
  "PostgreSQL", host = "localhost", port = 5432,
  dbname = "gis", user = "gisuser", password = "gisuser"
)

# helper functions -------------------------------------------------------------
concordance <- function(conn, fc1, fc2) {
  DBI::dbGetQuery(
    conn,
    sprintf(
      "
      with grp as
      (
        select
          *, rank() over (partition by code1 order by area desc) rn
        from
        (
          select
            a.code as code1,
            a.description as description1,
            b.code as code2,
            b.description as description2,
            ST_AREA(ST_INTERSECTION(a.geom, b.geom)) as area,
            ST_CENTROID(a.geom) as g1,
            ST_CENTROID(b.geom) as g2,
            ST_CENTROID(ST_INTERSECTION(a.geom, b.geom)) as g3
          from
            %s a
          inner join
            %s b
          on
            ST_INTERSECTS(a.geom, b.geom)
        ) c
      )
      select
        code1, description1, code2, description2,
        ST_X(g1) as x1, ST_Y(g1) as y1,
        ST_X(ST_TRANSFORM(g1, 4326)) as lng1,
        ST_Y(ST_TRANSFORM(g1, 4326)) as lat1,
        ST_X(g2) as x2, ST_Y(g2) as y2,
        ST_X(ST_TRANSFORM(g2, 4326)) as lng2,
        ST_Y(ST_TRANSFORM(g2, 4326)) as lat2,
        ST_X(g3) as x_int, ST_Y(g1) as y_int,
        ST_X(ST_TRANSFORM(g3, 4326)) as lng_int,
        ST_Y(ST_TRANSFORM(g3, 4326)) as lat_int
      from
        grp
      where
        rn = 1;
      ", fc1, fc2
    )
  )
}

conc1 <- function(x, geo1, geo2) {
  e <- setNames(
    c("code2", "code1", "description1"),
    c(geo2, sprintf("%s_%s", geo1, c("code", "description")))
  ) |> rlang::syms()

  x |>
    arrange(code2, code1) |>
    select(code2, code1, description1, x1, y1, lng1, lat1) |>
    rename(x = x1, y = y1, lng = lng1, lat = lat1) |>
    rename(!!!e)
}

conc2 <- function(x, geo1, geo2) {
  e <- setNames(
    c("code1", "code2", "description2"),
    c(geo1, sprintf("%s_%s", geo2, c("code", "description")))
  ) |> rlang::syms()

  x |>
    arrange(code1) |>
    select(code1, code2, description2) |>
    rename(!!!e)
}

# postcode concordances --------------------------------------------------------
## polygons smaller than postcodes ---------------------------------------------
# things that are smaller _might_ lie mostly inside a postcode.
# so, roughly many-to-one...
au_postcode <- concordance(conn, "au", "postcode") |>
  conc1("area_unit", "postcode")

sa2_postcode <- concordance(conn, "sa2", "postcode") |>
  conc1("statistical_area_2", "postcode")

suburb_postcode <- concordance(conn, "suburb", "postcode") |>
  conc1("suburb_locality", "postcode")

mb_postcode <- concordance(conn, "mb", "postcode") |>
  conc1("meshblock", "postcode")

# export
data.table::fwrite(au_postcode, file = "out/au_postcode.csv.gz")
data.table::fwrite(sa2_postcode, file = "out/sa2_postcode.csv.gz")
data.table::fwrite(suburb_postcode, file = "out/suburb_postcode.csv.gz")
data.table::fwrite(mb_postcode, file = "out/mb_postcode.csv.gz")

## polygons bigger than postcode -----------------------------------------------
# things that are bigger _might_ mostly enclose whole postcodes.
# so, roughly one-to-many...
postcode_rc <- concordance(conn, "postcode", "rc") |>
  conc2("postcode", "regc")

postcode_ta <- concordance(conn, "postcode", "ta") |>
  conc2("postcode", "ta")

# put the one-to-many relations in a single data frame
postcode_hg <- postcode_rc |>
  left_join(postcode_ta, by = "postcode")

# export
data.table::fwrite(postcode_hg, file = "out/postcode_hg.csv.gz")

# attach postcode to LINZ addresses --------------------------------------------
addr_w_postcode <- DBI::dbGetQuery(
  conn,
  "
  select
    a.address_id, a.full_address, b.code as postcode,
    ST_X(a.geom) as x, ST_Y(a.geom) as y,
    ST_X(ST_TRANSFORM(a.geom, 4326)) as lng,
    ST_Y(ST_TRANSFORM(a.geom, 4326)) as lat
  from
    address a
  left outer join
    postcode b
  on
    ST_CONTAINS(b.geom, a.geom)
  "
)

data.table::fwrite(addr_w_postcode, file = "out/address_w_postcode.csv.gz")
data.table::fwrite(addr_w_postcode |> select(address_id, postcode), file = "out/address_id_postcode.csv.gz")
