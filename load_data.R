library(sf)
library(dplyr)

# postcode ---------------------------------------------------------------------
postcode <- st_read("data/postcode.gpkg") |>
  st_transform(2193) |>
  mutate(description = code) |>
  select(code, description)

# meshblock --------------------------------------------------------------------
# to be uniform, lets just repeat the code as the mb description
mb <- st_read("data/meshblock-2022-clipped-generalised.gpkg") |>
  st_transform(2193) |>
  rename(code = MB2022_V1_00) |>
  mutate(description = code) |>
  select(code, description)

# suburb -----------------------------------------------------------------------
suburb <- st_read("data/nz-suburbs-and-localities-pilot.gpkg") |>
  st_transform(2193) |>
  mutate(
    code = suburb_locality_ascii,
    description = suburb_locality
  ) |>
  select(
    code, description,
    suburb_locality, additional_name, type, major_name, major_name_type
  )

# area unit --------------------------------------------------------------------
au <- st_read("data/area-unit-2013.gpkg") |>
  st_transform(2193) |>
  rename(code = AU2013_V1_00, description = AU2013_V1_00_NAME) |>
  select(code, description)

# sa2 --------------------------------------------------------------------------
sa2 <- st_read("data/statistical-area-2-2022-clipped-generalised.gpkg") |>
  st_transform(2193) |>
  rename(code = SA22022_V1_00, description = SA22022_V1_00_NAME) |>
  select(code, description)

# ta ---------------------------------------------------------------------------
ta <- st_read("data/territorial-authority-2022-clipped-generalised.gpkg") |>
  st_transform(2193) |>
  rename(code = TA2022_V1_00, description = TA2022_V1_00_NAME) |>
  select(code, description)

# regional council -------------------------------------------------------------
rc <- st_read("data/regional-council-2022-clipped-generalised.gpkg") |>
  st_transform(2193) |>
  rename(code = REGC2022_V1_00, description = REGC2022_V1_00_NAME) |>
  select(code, description)

# address ----------------------------------------------------------------------
addr <- st_read("data/nz-street-address.gpkg") |>
  st_transform(2193)

colnames(addr) <- tolower(colnames(addr))

# load to postgis --------------------------------------------------------------
conn <- RPostgreSQL::dbConnect(
  "PostgreSQL", host = "localhost", port = 5432,
  dbname = "gis", user = "gisuser", password = "gisuser"
)

st_write(postcode, conn, c("public", "postcode"))
st_write(mb, conn, c("public", "mb"))
st_write(suburb, conn, c("public", "suburb"))
st_write(au, conn, c("public", "au"))
st_write(sa2, conn, c("public", "sa2"))
st_write(ta, conn, c("public", "ta"))
st_write(rc, conn, c("public", "rc"))
st_write(addr, conn, c("public", "address"))

DBI::dbSendQuery(
  conn,
  '
  CREATE INDEX postcode_idx
  ON postcode
  USING GIST (geom);
  '
)

DBI::dbSendQuery(
  conn,
  '
  CREATE INDEX mb_idx
  ON mb
  USING GIST (geom);
  '
)

DBI::dbSendQuery(
  conn,
  '
  CREATE INDEX suburb_idx
  ON suburb
  USING GIST (geom);
  '
)

DBI::dbSendQuery(
  conn,
  '
  CREATE INDEX au_idx
  ON au
  USING GIST (geom);
  '
)

DBI::dbSendQuery(
  conn,
  '
  CREATE INDEX sa2_idx
  ON sa2
  USING GIST (geom);
  '
)

DBI::dbSendQuery(
  conn,
  '
  CREATE INDEX ta_idx
  ON ta
  USING GIST (geom);
  '
)

DBI::dbSendQuery(
  conn,
  '
  CREATE INDEX rc_idx
  ON rc
  USING GIST (geom);
  '
)

DBI::dbSendQuery(
  conn,
  '
  CREATE INDEX addr_idx
  ON address
  USING GIST (geom);
  '
)

# tidy up ----------------------------------------------------------------------
DBI::dbDisconnect(conn)
rm(list = ls())
