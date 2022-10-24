library(sf)
library(httr)

url <- "https://services2.arcgis.com/JCZKHUOTKN7eWpNb/arcgis/rest/services/APF_POSTCODES/FeatureServer/"
query <- sprintf("%s/0/query?where=1=1&returnGeometry=true&f=geojson&outSR=2193&outFields=POSTCODE", url)

postcode <- httr::GET(query) |> content(as = "text") |> st_read(quiet = TRUE) |> st_make_valid()
colnames(postcode) <- c("code", "geom")
st_geometry(postcode) <- "geom"

st_write(
  postcode,
  "data/postcode.gpkg", append = FALSE
)

st_write(
  postcode |> st_simplify(preserveTopology = TRUE, dTolerance = 10),
  "data/postcode_10m.gpkg", append = FALSE
)

st_write(
  postcode |> st_simplify(preserveTopology = TRUE, dTolerance = 5),
  "data/postcode_5m.gpkg", append = FALSE
)

st_write(
  postcode |> st_simplify(preserveTopology = TRUE, dTolerance = 1),
  "data/postcode_1m.gpkg", append = FALSE
)
